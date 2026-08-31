# frozen_string_literal: true

class Meta::Whatsapp::OutboundMessageSender
  class RetiredPath < StandardError; end
  class BlockedByControlState < StandardError; end
  MetaSendFailed = RetiredPath

  def initialize(conversation:, content:, expected_control_version:)
    # Preserve the retired service signature for stale call sites.
  end

  def perform
    raise RetiredPath, 'Use Message, SendReplyJob, and Whatsapp::SendOnWhatsappService for WhatsApp delivery'
  end
end
