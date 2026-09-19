# frozen_string_literal: true

class Api::V1::Accounts::HumanReviewRequestsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?, only: :assign
  before_action :check_authorization, only: :index
  before_action :review_request, only: [:show, :resolve, :assign, :reject, :propose_knowledge]

  def index
    render json: policy_scope(current_account.human_review_requests).operator_queue.map { |request| payload(request) }
  end

  def show
    render json: payload(@review_request)
  end

  def resolve
    @review_request.resolve_with!(
      answer: resolve_params[:answer],
      operator: Current.user,
      resolution_kind: resolution_kind,
      existing_message: existing_human_answer_message
    )
    render json: payload(@review_request.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def propose_knowledge
    @review_request.propose_knowledge!(
      proposer: Current.user,
      source_kind: proposal_params[:source_kind],
      title: proposal_params[:title]
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
    authorize @review_request, %w[resolve propose_knowledge].include?(params[:action]) ? :update? : :show?
  end

  def resolve_params
    params.permit(:human_answer_message_id, :answer, :resolution_kind, :send_to_lead)
  end

  def proposal_params
    params.permit(:source_kind, :title)
  end

  def assign_params
    params.permit(:assigned_user_id)
  end

  def resolution_kind
    return resolve_params[:resolution_kind] if %w[send_reply internal_note].include?(resolve_params[:resolution_kind])
    return 'send_reply' if resolve_params[:human_answer_message_id].present?

    ActiveModel::Type::Boolean.new.cast(resolve_params[:send_to_lead]) ? 'send_reply' : 'internal_note'
  end

  def existing_human_answer_message
    return if resolve_params[:human_answer_message_id].blank?

    answer = @review_request.conversation.messages.outgoing.where(private: false).find(resolve_params[:human_answer_message_id])
    return answer if answer.sender == Current.user

    @review_request.errors.add(:human_answer_message, 'must be sent by the resolving Human Operator')
    raise ActiveRecord::RecordInvalid, @review_request
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
      proposed_source_kind: request.proposed_source_kind,
      reply_outcome: reply_outcome(request),
      knowledge_proposal_outcome: knowledge_proposal_outcome(request),
      knowledge_proposal: knowledge_proposal_payload(request)
    }
  end

  def resolution_payload(request)
    {
      assigned_user: request.assigned_user && { id: request.assigned_user.id, name: request.assigned_user.name },
      operator_answer: request.operator_answer,
      resolution_kind: request.resolution_kind
    }
  end

  def reply_outcome(request)
    return 'not_resolved' unless request.resolved?
    return 'private_note_saved' if request.resolution_kind == 'internal_note'

    'reply_queued'
  end

  def knowledge_proposal_outcome(request)
    return 'draft_proposed' if request.knowledge_item_id.present?

    'not_requested'
  end

  def knowledge_proposal_payload(request)
    return unless request.knowledge_item

    {
      id: request.knowledge_item.id,
      status: request.knowledge_item.status,
      source_kind: request.knowledge_item.source_kind,
      offer_ids: request.knowledge_item.metadata.fetch('offer_ids', [])
    }
  end
end
