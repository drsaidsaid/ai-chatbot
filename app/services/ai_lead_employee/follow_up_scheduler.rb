# frozen_string_literal: true

class AiLeadEmployee::FollowUpScheduler
  def initialize(conversation:, qualification_result:)
    @conversation = conversation
    @qualification_result = qualification_result
    @account = conversation.account
    @contact = conversation.contact
  end

  def perform
    return cancel_pending!('no_unanswered_question') if question_text.blank?
    return cancel_pending!('ineligible_qualification') unless eligible_qualification?
    return cancel_pending!('follow_up_opted_out') if opted_out?
    return cancel_pending!('incompatible_control_state') unless compatible_conversation?
    return cancel_pending!('follow_up_disabled') unless config.enabled_for?(stage: stage, signal: signal)

    create_missing_attempts
  end

  def self.cancel_pending_for!(conversation:, reason:)
    LeadFollowUp.pending_for_conversation(conversation).find_each { |follow_up| follow_up.cancel!(reason) }
  end

  private

  attr_reader :account, :contact, :conversation, :qualification_result

  def create_missing_attempts
    max_attempts = config.max_attempts_for(stage: stage, signal: signal, quality: qualification.quality)

    (1..max_attempts).filter_map { |attempt_number| schedule_attempt!(attempt_number) }
  end

  def schedule_attempt!(attempt_number)
    follow_up = LeadFollowUp.find_or_initialize_by(
      account: account,
      contact: contact,
      stage: stage,
      attempt_number: attempt_number
    )
    return update_pending_attempt!(follow_up, attempt_number) unless follow_up.new_record?

    follow_up.assign_attributes(follow_up_attributes(attempt_number))
    follow_up.save!
    enqueue_delivery(follow_up)
    follow_up
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def update_pending_attempt!(follow_up, attempt_number)
    return unless follow_up.pending?
    return follow_up if pending_attempt_current?(follow_up)

    follow_up.update!(follow_up_attributes(attempt_number))
    enqueue_delivery(follow_up)
    follow_up
  end

  def pending_attempt_current?(follow_up)
    follow_up.question_text == question_text &&
      follow_up.content == rendered_content &&
      follow_up.control_version == conversation.control_version &&
      follow_up.qualification_question_id == qualification_question&.id
  end

  def enqueue_delivery(follow_up)
    AiLeadEmployee::FollowUpDeliveryJob.set(wait_until: follow_up.scheduled_at).perform_later(follow_up)
  end

  def follow_up_attributes(attempt_number)
    {
      conversation: conversation,
      lead_qualification: qualification,
      qualification_question: qualification_question,
      question_text: question_text,
      content: rendered_content,
      control_version: conversation.control_version,
      scheduled_at: scheduled_at_for(attempt_number)
    }
  end

  def rendered_content
    @rendered_content ||= config.render_message(question_text)
  end

  def scheduled_at_for(attempt_number)
    Time.current + (config.delay_for(stage: stage, signal: signal) * attempt_number)
  end

  def cancel_pending!(reason)
    self.class.cancel_pending_for!(conversation: conversation, reason: reason)
    []
  end

  def compatible_conversation?
    conversation.reload.ai_active? && conversation.open? && conversation.assignee_id.blank?
  end

  def opted_out?
    LeadFollowUpOptOut.exists?(account: account, contact: contact)
  end

  def eligible_qualification?
    return false if qualification.unqualified? || qualification.highly_qualified?
    return false if qualification.follow_up_state.in?(%w[human_review call_booked closed])

    true
  end

  def qualification
    qualification_result.qualification
  end

  def question_text
    qualification_result.next_question
  end

  def qualification_question
    @qualification_question ||= account.qualification_questions.enabled_in_order.find_by(prompt: question_text)
  end

  def signal
    qualification_question&.signal || qualification.missing_signals.first
  end

  def stage
    qualification.qualified? ? :qualified_nurture : :incomplete_qualification
  end

  def config
    @config ||= AiLeadEmployee::FollowUpConfig.new(account)
  end
end
