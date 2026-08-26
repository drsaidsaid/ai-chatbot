# frozen_string_literal: true

class AiLeadEmployee::FollowUpDeliveryService
  def initialize(follow_up:)
    @follow_up = follow_up
  end

  def perform
    follow_up.with_lock do
      return unless follow_up.pending?

      if opted_out?
        follow_up.cancel!('follow_up_opted_out')
        return
      end

      unless compatible_conversation?
        follow_up.cancel!('incompatible_control_state')
        return
      end

      send_follow_up!
    rescue Meta::Whatsapp::OutboundMessageSender::BlockedByControlState
      follow_up.cancel!('incompatible_control_state')
    rescue Meta::Whatsapp::OutboundMessageSender::MetaSendFailed => e
      fail_follow_up!(e.message)
    end
  end

  private

  attr_reader :follow_up

  def send_follow_up!
    message = Meta::Whatsapp::OutboundMessageSender.new(
      conversation: conversation,
      content: follow_up.content,
      expected_control_version: follow_up.control_version
    ).perform
    follow_up.update!(status: :sent, message: message, sent_at: Time.current)
  end

  def fail_follow_up!(reason)
    follow_up.update!(status: :failed, failure_reason: reason, failed_at: Time.current)
  end

  def compatible_conversation?
    conversation.reload.ai_active? &&
      conversation.open? &&
      conversation.assignee_id.blank? &&
      conversation.control_version == follow_up.control_version
  end

  def opted_out?
    LeadFollowUpOptOut.exists?(account: follow_up.account, contact: follow_up.contact)
  end

  def conversation
    follow_up.conversation
  end
end
