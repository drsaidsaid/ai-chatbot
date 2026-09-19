# frozen_string_literal: true

class Api::V1::Accounts::ReviewConfigurationSuggestionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :suggestion, only: :review

  def index
    suggestions = current_account.review_configuration_suggestions.pending.order(created_at: :asc)
    render json: suggestions.map { |record| payload(record) }
  end

  def review
    @suggestion.review!(
      reviewer: Current.user,
      outcome: review_outcome,
      decision_note: review_params[:decision_note]
    )
    render json: payload(@suggestion.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def suggestion
    @suggestion = current_account.review_configuration_suggestions.find(params[:id])
  end

  def review_params
    params.permit(:outcome, :decision_note)
  end

  def review_outcome
    outcome = review_params[:outcome].to_s
    return outcome if %w[reviewed dismissed].include?(outcome)

    @suggestion.errors.add(:status, 'is not supported')
    raise ActiveRecord::RecordInvalid, @suggestion
  end

  def payload(record)
    {
      id: record.id,
      category: record.category,
      status: record.status,
      suggestion: record.suggestion,
      evidence: record.evidence,
      conversation_id: record.conversation_id,
      conversation_display_id: record.conversation.display_id,
      offer_id: record.offer_id,
      source_type: record.lead_handoff_id? ? 'lead_handoff' : 'human_review_request',
      source_id: record.lead_handoff_id || record.human_review_request_id,
      proposed_by_user_id: record.proposed_by_user_id,
      reviewed_by_user_id: record.reviewed_by_user_id,
      reviewed_at: record.reviewed_at,
      decision_note: record.decision_note,
      created_at: record.created_at
    }
  end
end
