# frozen_string_literal: true

class AiLeadEmployee::FollowUpDeliveryService
  OUTBOX_EVENT_TYPE = 'ai_employee.follow_up_recorded'

  def initialize(follow_up:)
    @follow_up = follow_up
  end

  def perform
    outbox_event_id = nil

    follow_up.with_lock do
      return unless follow_up.pending?

      if opted_out?
        follow_up.cancel!('follow_up_opted_out')
        return
      end

      return cancel_internal_note! if internal_note?

      unless compatible_conversation?
        follow_up.cancel!('incompatible_control_state')
        return
      end

      outbox_event_id = record_follow_up!
    end

    AiLeadEmployee::OutboxDispatchJob.perform_later(outbox_event_id) if outbox_event_id.present?
  end

  private

  attr_reader :follow_up

  def record_follow_up!
    conversation.with_lock do
      unless compatible_conversation_state?
        follow_up.cancel!('incompatible_control_state')
        return
      end

      return reschedule_delivery! if follow_up.scheduled_at.future?

      message = follow_up.message || create_follow_up_message!
      follow_up.update!(message: message)
      create_outbox_event!(message).id
    end
  end

  def create_outbox_event!(message)
    OutboxEvent.find_or_create_by!(account: follow_up.account, idempotency_key: "ai-follow-up/#{follow_up.id}") do |event|
      event.aggregate = message
      event.event_type = OUTBOX_EVENT_TYPE
      event.payload = {
        message_id: message.id,
        conversation_id: conversation.id,
        follow_up_id: follow_up.id,
        channel: 'whatsapp'
      }
    end
  end

  def create_follow_up_message!
    conversation.messages.create!(
      account: follow_up.account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: follow_up.content,
      private: false,
      additional_attributes: follow_up_message_attributes
    )
  end

  def reschedule_delivery!
    AiLeadEmployee::FollowUpDeliveryJob.set(wait_until: follow_up.scheduled_at).perform_later(follow_up)
    nil
  end

  def follow_up_message_attributes
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        follow_up_id: follow_up.id,
        delivery_type: 'qualification_follow_up'
      }
    }
  end

  def compatible_conversation?
    conversation.reload
    compatible_conversation_state?
  end

  def compatible_conversation_state?
    conversation.ai_active? &&
      conversation.open? &&
      conversation.assignee_id.blank? &&
      conversation.control_version == follow_up.control_version
  end

  def opted_out?
    LeadFollowUpOptOut.exists?(account: follow_up.account, contact: follow_up.contact)
  end

  def internal_note?
    follow_up.message&.private?
  end

  def cancel_internal_note!
    follow_up.cancel!('internal_note')
  end

  def conversation
    follow_up.conversation
  end
end
