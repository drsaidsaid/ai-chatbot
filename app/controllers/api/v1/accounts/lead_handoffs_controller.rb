# frozen_string_literal: true

class Api::V1::Accounts::LeadHandoffsController < Api::V1::Accounts::BaseController
  before_action :lead_handoff

  def show
    render json: payload
  end

  def propose_configuration_suggestion
    @lead_handoff.propose_configuration_suggestion!(
      proposer: Current.user,
      category: suggestion_category,
      suggestion: suggestion_params[:suggestion]
    )
    render json: payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def lead_handoff
    @lead_handoff = current_account.lead_handoffs.find(params[:id])
    authorize @lead_handoff, params[:action] == 'show' ? :show? : :update?
  end

  def suggestion_params
    params.permit(:category, :suggestion)
  end

  def suggestion_category
    category = suggestion_params[:category].to_s
    return category if ReviewConfigurationSuggestion.categories.key?(category)

    @lead_handoff.errors.add(:category, 'is not supported')
    raise ActiveRecord::RecordInvalid, @lead_handoff
  end

  def payload
    suggestion = @lead_handoff.configuration_suggestion
    {
      id: @lead_handoff.id,
      conversation_id: @lead_handoff.conversation_id,
      status: @lead_handoff.status,
      offer_id: @lead_handoff.lead_qualification.offer_id,
      configuration_suggestion_outcome: suggestion&.status || 'not_requested',
      configuration_suggestion: suggestion && suggestion_payload(suggestion),
      can_review_configuration_suggestion: Current.account_user&.administrator? || false
    }
  end

  def suggestion_payload(suggestion)
    suggestion.slice(
      :id, :category, :status, :suggestion, :evidence, :offer_id, :conversation_id,
      :proposed_by_user_id, :reviewed_by_user_id, :reviewed_at, :decision_note
    )
  end
end
