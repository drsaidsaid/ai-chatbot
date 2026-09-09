# frozen_string_literal: true

# Meta receives only this purpose-bound, short-lived capability from the sender.
class WhatsappMediaController < ApplicationController
  include ActiveStorage::Streaming

  def show
    attachment = Attachment.find_signed(params[:token], purpose: :whatsapp_media)
    return head :not_found unless attachment&.file&.attached?
    return head :forbidden unless deliverable?(attachment.message)

    response.headers['Cache-Control'] = 'private, no-store'
    send_blob_stream(attachment.file.blob, disposition: 'inline')
  end

  private

  def deliverable?(message)
    return false unless message.outgoing? && !message.private? && message.inbox.whatsapp? && message.account.active?
    return true unless message.sender.is_a?(User)

    AiLeadEmployee::AccessScope.new(account: message.account, user: message.sender).conversations.exists?(id: message.conversation_id)
  end
end
