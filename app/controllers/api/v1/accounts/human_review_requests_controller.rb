# frozen_string_literal: true

class Api::V1::Accounts::HumanReviewRequestsController < Api::V1::Accounts::BaseController
  before_action :check_authorization, only: :index
  before_action :review_request, only: [:show, :resolve]

  def index
    render json: policy_scope(current_account.human_review_requests).operator_queue.map { |request| payload(request) }
  end

  def show
    render json: payload(@review_request)
  end

  def resolve
    answer = @review_request.conversation.messages.outgoing.where(private: false).find(resolve_params[:human_answer_message_id])
    unless answer.sender.is_a?(User)
      return render json: { error: 'Human answer message must be sent by a Human Operator' },
                    status: :unprocessable_entity
    end

    @review_request.resolve!(
      human_answer_message: answer,
      proposer: Current.user,
      propose_knowledge: resolve_params[:propose_knowledge],
      source_kind: resolve_params[:source_kind],
      title: resolve_params[:title]
    )
    render json: payload(@review_request.reload)
  end

  private

  def review_request
    @review_request = current_account.human_review_requests.find(params[:id])
    authorize @review_request, params[:action] == 'resolve' ? :update? : :show?
  end

  def resolve_params
    params.permit(:human_answer_message_id, :propose_knowledge, :source_kind, :title)
  end

  def payload(request)
    {
      id: request.id,
      status: request.status,
      reason: request.reason,
      question: request.question,
      conversation_id: request.conversation_id,
      conversation_display_id: request.conversation.display_id,
      lead_message_id: request.lead_message_id,
      human_answer_message_id: request.human_answer_message_id,
      knowledge_item_id: request.knowledge_item_id,
      proposed_source_kind: request.proposed_source_kind,
      alert_recipients: request.alert_recipients,
      alert_deliveries: request.alert_deliveries,
      created_at: request.created_at,
      resolved_at: request.resolved_at
    }
  end
end
