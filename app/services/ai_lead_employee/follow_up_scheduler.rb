# frozen_string_literal: true

class AiLeadEmployee::FollowUpScheduler
  def initialize(conversation:, qualification_result:)
    @conversation = conversation
    @qualification_result = qualification_result
    @account = conversation.account
    @contact = conversation.contact
  end

  def perform # rubocop:disable Metrics/AbcSize
    conversation.reload.with_lock('FOR NO KEY UPDATE') do
      existing = LeadFollowUp.where(account: account, contact: contact).to_a
      AiLeadEmployee::FollowUpCancellation.lock_offers!(conversations: [conversation], follow_ups: existing,
                                                        additional_offer_ids: [qualification_context['offer_id']])
      return cancel_pending!('no_unanswered_question') if question_text.blank?
      return cancel_pending!('ineligible_qualification') unless eligible_qualification?
      return cancel_pending!('follow_up_opted_out') if opted_out?
      return cancel_pending!('incompatible_control_state') unless compatible_conversation?
      return cancel_pending!('follow_up_disabled') unless config.enabled_for?(stage: stage, signal: signal)
      return [] if context_guard.failure_code

      create_missing_attempts
    end
  end

  def self.cancel_pending_for!(conversation:, reason:)
    AiLeadEmployee::FollowUpCancellation.call(
      follow_ups: LeadFollowUp.all,
      conversation_scope: Conversation.where(account_id: conversation.account_id, id: conversation.id),
      reason: reason
    )
  end

  private

  attr_reader :account, :contact, :conversation, :qualification_result

  def create_missing_attempts # rubocop:disable Metrics/AbcSize
    max_attempts = config.max_attempts_for(stage: stage, signal: signal, quality: qualification.quality)
    # Own FK parents before creating any A/F row; KEY SHARE permits ordinary
    # identity edits and only protects the referenced keys against replacement.
    Account.where(id: account.id).lock('FOR KEY SHARE').load
    Contact.where(id: contact.id).lock('FOR KEY SHARE').load
    LeadQualification.where(id: qualification.id).lock('FOR KEY SHARE').load
    QualificationQuestion.where(id: qualification_question&.id).lock('FOR KEY SHARE').load

    # create_or_find_by! locks an existing conflicting row implicitly. Discover
    # and lock ALL existing attempts by ID first, irrespective of attempt_number
    # order in historical data. Missing rows receive fresh, higher IDs afterward.
    scope = LeadFollowUpAttempt.where(account: account, contact: contact, offer_id: qualification.offer_id, stage: stage)
    attempts = scope.where(attempt_number: 1..max_attempts).order(:id).lock('FOR NO KEY UPDATE').to_a
    missing_numbers = (1..max_attempts).to_a - attempts.map(&:attempt_number)
    missing_numbers.each { |number| attempts << scope.create_or_find_by!(attempt_number: number) }
    current_ids = attempts.filter_map(&:current_follow_up_id)
    Whatsapp::DeliveryLifecycle.with(follow_ups: LeadFollowUp.where(id: current_ids)) do |owner|
      attempts.filter_map { |attempt| schedule_attempt!(attempt, owner) }
    end
  end

  def schedule_attempt!(attempt, owner)
    return unless attempt.replaceable?

    previous = owner.follow_ups[attempt.current_follow_up_id]
    if previous
      return previous if previous.pending? && pending_attempt_current?(previous)
      return unless replacement_allowed?(attempt, previous, owner)

      owner.cancel_artifact!(previous, reason: @replacement_reason)
      previous.update!(superseded_at: Time.current, replacement_reason: @replacement_reason)
    end
    follow_up = LeadFollowUp.create!(follow_up_attributes(attempt.attempt_number).merge(
                                       account: account, contact: contact, stage: stage, attempt_number: attempt.attempt_number,
                                       follow_up_attempt: attempt, replaces_follow_up: previous
                                     ))
    previous&.update!(replaced_by_follow_up: follow_up)
    attempt.update!(current_follow_up: follow_up)
    enqueue_delivery(follow_up)
    follow_up
  end

  def replacement_allowed?(attempt, previous, owner) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return false unless owner.current?(previous) && previous.conversation_id == conversation.id
    return false unless previous.pending? || (previous.cancelled? && LeadFollowUp::CONTEXT_REPLACEMENT_REASONS.include?(previous.cancellation_reason))

    if attempt.offer_id.nil?
      owner.cancel_artifact!(previous, reason: 'legacy_question_changed')
      return false
    end
    return false if previous.qualification_context.blank?

    @replacement_reason = AiLeadEmployee::OfferDeliveryContext.new(conversation: conversation, context: previous.qualification_context,
                                                                   required: true).failure_code
    return false unless LeadFollowUp::CONTEXT_REPLACEMENT_REASONS.include?(@replacement_reason)

    delivery = owner.deliveries.values.find { |row| row.message_id == previous.message_id }
    return true unless delivery
    return false if delivery.dispatch_started_at.present?

    delivery.pending? || delivery.claimed? || (delivery.canceled? && LeadFollowUp::CONTEXT_REPLACEMENT_REASONS.include?(delivery.failure_code))
  end

  def pending_attempt_current?(follow_up)
    follow_up.conversation_id == conversation.id && follow_up.question_text == question_text &&
      follow_up.content == rendered_content && follow_up.qualification_context == qualification_context &&
      follow_up.control_version == conversation.control_version && follow_up.qualification_question_id == qualification_question&.id
  end

  def qualification_context
    qualification_result.qualification_context.to_h
  end

  def context_guard
    @context_guard ||= AiLeadEmployee::OfferDeliveryContext.new(conversation: conversation, context: qualification_context,
                                                                required: qualification.offer_id.present?)
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
      question_key: qualification_result.next_question_key || qualification_question&.signal,
      qualification_context: qualification_context,
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
    qualification_result.next_question_key || qualification_question&.signal || qualification.missing_signals.first
  end

  def stage
    qualification.qualified? ? :qualified_nurture : :incomplete_qualification
  end

  def config
    @config ||= AiLeadEmployee::FollowUpConfig.new(account)
  end
end
