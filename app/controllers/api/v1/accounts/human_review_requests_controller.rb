# frozen_string_literal: true

class Api::V1::Accounts::HumanReviewRequestsController < Api::V1::Accounts::BaseController # rubocop:disable Metrics/ClassLength
  before_action :check_admin_authorization?, only: :assign
  before_action :check_authorization, only: :index
  before_action :review_request,
                only: [:show, :resolve, :assign, :reject, :propose_knowledge, :propose_configuration_suggestion,
                       :review_configuration_suggestion]

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
    knowledge_item = @review_request.propose_knowledge!(
      proposer: Current.user,
      source_kind: proposal_source_kind,
      title: proposal_params[:title],
      answer: proposal_params[:answer]
    )
    AiLeadEmployee::KnowledgeApprovalAlertDeliveryService.new(knowledge_item: knowledge_item).perform
    render json: payload(@review_request.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def propose_configuration_suggestion
    @review_request.propose_configuration_suggestion!(
      proposer: Current.user,
      category: configuration_suggestion_category,
      suggestion: configuration_suggestion_params[:suggestion]
    )
    render json: payload(@review_request.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def review_configuration_suggestion
    suggestion = @review_request.configuration_suggestion
    raise ActiveRecord::RecordNotFound unless suggestion

    suggestion.review!(
      reviewer: Current.user,
      outcome: configuration_review_outcome,
      decision_note: configuration_review_params[:decision_note]
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
    update_actions = %w[resolve propose_knowledge propose_configuration_suggestion review_configuration_suggestion]
    authorize @review_request, update_actions.include?(params[:action]) ? :update? : :show?
  end

  def resolve_params
    params.permit(:human_answer_message_id, :answer, :resolution_kind, :send_to_lead)
  end

  def proposal_params
    params.permit(:source_kind, :title, :answer)
  end

  def configuration_suggestion_params
    params.permit(:category, :suggestion)
  end

  def configuration_review_params
    params.permit(:outcome, :decision_note)
  end

  def configuration_suggestion_category
    category = configuration_suggestion_params[:category].to_s
    return category if ReviewConfigurationSuggestion.categories.key?(category)

    @review_request.errors.add(:category, 'is not supported')
    raise ActiveRecord::RecordInvalid, @review_request
  end

  def configuration_review_outcome
    outcome = configuration_review_params[:outcome].to_s
    return outcome if %w[reviewed dismissed].include?(outcome)

    @review_request.configuration_suggestion.errors.add(:status, 'is not supported')
    raise ActiveRecord::RecordInvalid, @review_request.configuration_suggestion
  end

  def proposal_source_kind
    source_kind = proposal_params[:source_kind].to_s
    return source_kind if KnowledgeItem.source_kinds.key?(source_kind)

    @review_request.errors.add(:source_kind, 'is not supported')
    raise ActiveRecord::RecordInvalid, @review_request
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
      reply_delivery: reply_delivery_payload(request),
      knowledge_proposal_outcome: knowledge_proposal_outcome(request),
      knowledge_proposal: knowledge_proposal_payload(request),
      configuration_suggestion_outcome: configuration_suggestion_outcome(request),
      configuration_suggestion: configuration_suggestion_payload(request),
      can_review_configuration_suggestion: Current.account_user&.administrator? || false
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

    message = request.human_answer_message
    provider_status = message&.content_attributes&.fetch('whatsapp_provider_status', nil)
    return "reply_delivery_#{provider_status}" if Whatsapp::MessageStatusProjector::STATUSES.include?(provider_status)

    delivery = message&.whatsapp_outbound_delivery
    return 'reply_pending_delivery' unless delivery

    "reply_delivery_#{delivery.state}"
  end

  def knowledge_proposal_outcome(request)
    return 'draft_proposed' if request.knowledge_item_id.present?

    'not_requested'
  end

  def reply_delivery_payload(request)
    message = request.human_answer_message
    return unless request.resolution_kind == 'send_reply' && message

    delivery = message.whatsapp_outbound_delivery
    {
      outcome: reply_outcome(request),
      provider_status: message.content_attributes['whatsapp_provider_status'],
      authority_state: delivery&.state,
      failure_code: message.content_attributes['whatsapp_delivery_error_code'] || delivery&.failure_code,
      recoverable: delivery&.failed? && delivery.attempts < Whatsapp::OutboundDelivery::MAX_CLAIM_ATTEMPTS &&
        message.source_id.blank?
    }
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

  def configuration_suggestion_outcome(request)
    request.configuration_suggestion&.status || 'not_requested'
  end

  def configuration_suggestion_payload(request)
    suggestion = request.configuration_suggestion
    return unless suggestion

    {
      id: suggestion.id,
      category: suggestion.category,
      status: suggestion.status,
      suggestion: suggestion.suggestion,
      evidence: suggestion.evidence,
      offer_id: suggestion.offer_id,
      source_message_id: suggestion.source_message_id,
      conversation_id: suggestion.conversation_id,
      proposed_by_user_id: suggestion.proposed_by_user_id,
      reviewed_by_user_id: suggestion.reviewed_by_user_id,
      reviewed_at: suggestion.reviewed_at,
      decision_note: suggestion.decision_note
    }
  end
end # rubocop:enable Metrics/ClassLength
