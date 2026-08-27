# frozen_string_literal: true

class Api::V1::Accounts::HumanReviewRequestsController < Api::V1::Accounts::BaseController
  before_action :check_authorization, only: :index
  before_action :review_request, only: [:show, :resolve, :assign, :reject]

  def index
    render json: policy_scope(current_account.human_review_requests).operator_queue.map { |request| payload(request) }
  end

  def show
    render json: payload(@review_request)
  end

  def resolve
    answer = human_answer_message
    return if answer.blank?

    @review_request.resolve!(
      human_answer_message: answer,
      proposer: Current.user,
      propose_knowledge: resolve_params[:propose_knowledge],
      source_kind: resolve_params[:source_kind],
      title: resolve_params[:title]
    )
    render json: payload(@review_request.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def assign
    user = current_account.users.find(assign_params[:assigned_user_id])
    @review_request.assign_to!(user)
    render json: payload(@review_request.reload)
  end

  def reject
    @review_request.reject!(operator_answer: params[:operator_answer])
    render json: payload(@review_request.reload)
  end

  private

  def review_request
    @review_request = current_account.human_review_requests.find(params[:id])
    authorize @review_request, params[:action] == 'resolve' ? :update? : :show?
  end

  def resolve_params
    params.permit(:human_answer_message_id, :answer, :send_to_lead, :propose_knowledge, :source_kind, :title)
  end

  def assign_params
    params.permit(:assigned_user_id)
  end

  def human_answer_message
    return existing_human_answer_message if resolve_params[:human_answer_message_id].present?

    @review_request.conversation.messages.create!(
      account: current_account,
      inbox: @review_request.conversation.inbox,
      sender: Current.user,
      message_type: :outgoing,
      private: !ActiveModel::Type::Boolean.new.cast(resolve_params[:send_to_lead]),
      content: resolve_params[:answer]
    )
  end

  def existing_human_answer_message
    answer = @review_request.conversation.messages.outgoing.where(private: false).find(resolve_params[:human_answer_message_id])
    return answer if answer.sender.is_a?(User)

    render json: { error: 'Human answer message must be sent by a Human Operator' }, status: :unprocessable_entity
    nil
  end

  def payload(request)
    base_payload(request).merge(
      resolution_payload(request),
      alert_recipients: request.alert_recipients,
      alert_deliveries: request.alert_deliveries,
      created_at: request.created_at,
      resolved_at: request.resolved_at,
      rejected_at: request.rejected_at
    )
  end

  def base_payload(request)
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
      proposed_source_kind: request.proposed_source_kind
    }
  end

  def resolution_payload(request)
    {
      assigned_user: request.assigned_user && { id: request.assigned_user.id, name: request.assigned_user.name },
      operator_answer: request.operator_answer,
      resolution_kind: request.resolution_kind
    }
  end
end
