module Api::V1::Accounts::Concerns::ConversationAiControl
  extend ActiveSupport::Concern

  private

  def control_ai!(action)
    authorize @conversation, :control?
    result = Conversations::ControlService.new(conversation: @conversation, actor: Current.user).public_send(action)
    AiLeadEmployee::BotHandoffDispatchJob.perform_later(result.id) if action == :handoff_requested!
  rescue Conversations::ControlService::InvalidTransition => e
    render_could_not_create_error(e.message)
  end

  def requested_status
    params[:status].presence || (@conversation.open? ? 'resolved' : 'open')
  end

  def bot_handoff?
    return false unless Current.user.is_a?(AgentBot) && params[:status] == 'open'

    (@conversation.pending? && @conversation.ai_active?) || (@conversation.open? && @conversation.handoff_requested?)
  end

  def transition_human_status!(status)
    service = Conversations::ControlService.new(conversation: @conversation, actor: Current.user)
    @status = case status
              when 'resolved'
                service.resolve!
              when 'open'
                service.open_for_human!(operator: human_operator)
              else
                service.update_inbox_status!(status: status, snoozed_until: requested_snoozed_until)
              end
  end

  def human_operator
    Current.user if Current.user.agent?
  end

  def requested_snoozed_until
    parse_date_time(params[:snoozed_until].to_s) if params[:snoozed_until]
  end
end
