module Api::V1::Accounts::Concerns::ConversationAiControl
  extend ActiveSupport::Concern

  private

  def control_ai!(action)
    authorize @conversation, :control?
    Conversations::ControlService.new(conversation: @conversation).public_send(action)
  rescue Conversations::ControlService::InvalidTransition => e
    render_could_not_create_error(e.message)
  end
end
