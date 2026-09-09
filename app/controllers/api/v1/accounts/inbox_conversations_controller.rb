class Api::V1::Accounts::InboxConversationsController < Api::V1::Accounts::BaseController
  def show
    render json: AiLeadEmployee::InboxConversations.new(
      scope: policy_scope(Current.account.conversations),
      user: Current.user,
      filters: params.permit(:queue, :q, :quality, :follow_up_state, :assignee_id, :source_id, :booking_status, :follow_up_status, :page)
    ).perform
  end
end
