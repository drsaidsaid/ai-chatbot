# frozen_string_literal: true

class Api::V1::Accounts::QualificationOffersController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def index
    render json: current_account.qualification_offers.order(:position, :id).map(&:payload)
  end

  def show
    render json: offer.payload
  end

  def create
    save_offer(current_account.qualification_offers.new, :created)
  end

  def update
    save_offer(offer, :ok)
  end

  def update_commercial_terms
    AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: commercial_terms_params,
      expected_version: params[:draft_version]
    )
    render json: offer.reload.payload
  rescue AiLeadEmployee::CommercialTerms::Conflict => e
    render json: { error: e.message }, status: :conflict
  rescue ArgumentError, KeyError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def publish_commercial_terms
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: params.require(:draft_version), editor: Current.user)
    render json: offer.reload.payload
  rescue AiLeadEmployee::CommercialTerms::Conflict => e
    render json: { error: e.message }, status: :conflict
  rescue ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def preview_commercial_terms
    result = AiLeadEmployee::OfferPricingResolver.new(
      account: current_account,
      offer: offer,
      at: preview_time,
      promotion_eligible: preview_promotion_eligible
    ).perform
    render json: {
      answer: result.answer,
      answered: result.answered?,
      refusal_reason: result.refusal_reason,
      pricing_variant: result.variant,
      sources: result.sources
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def approve_commercial_proposal
    proposal = offer.commercial_proposals.find(params[:proposal_id])
    record = AiLeadEmployee::CommercialProposalReviewer.new(offer: offer, proposal: proposal, reviewer: Current.user).approve!
    render json: offer.reload.payload.merge('commercial_terms_draft' => record.draft_payload)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reject_commercial_proposal
    proposal = offer.commercial_proposals.find(params[:proposal_id])
    AiLeadEmployee::CommercialProposalReviewer.new(offer: offer, proposal: proposal, reviewer: Current.user).reject!
    render json: offer.reload.payload
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def offer
    @offer ||= current_account.qualification_offers.find(params[:id])
  end

  def save_offer(record, status)
    saved = AiLeadEmployee::OfferConfigurationWriter.new(offer: record, attributes: offer_params.to_h).perform
    render json: saved.payload, status: status
  rescue AiLeadEmployee::OfferConfigurationWriter::Conflict => e
    render json: { error: e.message }, status: :conflict
  rescue ArgumentError, KeyError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def offer_params
    permitted = params.require(:offer).permit(:name, :currency, :enabled, :version, :qualification_mode,
                                              questions: [
                                                :key, :meaning, :answer_type, :prompt, :position, :enabled, :required,
                                                :period, :purpose, { options: [] }
                                              ],
                                              next_step: [:kind, :prompt, :url],
                                              budget_ranges: [:label, :minimum, :maximum, :position, :enabled],
                                              score_weights: {}, score_thresholds: [:qualified, :highly_qualified]).to_h
    permitted.merge('rules' => rule_params, 'requirement_groups' => requirement_group_params)
  end

  def commercial_terms_params
    params.require(:commercial_terms).permit(
      :amount, :currency, :quote_required, :effective_from, :effective_until, :timezone, :conditions, :pricing_url,
      :promotion_amount, :promotion_starts_at, :promotion_ends_at, :promotion_conditions, :promotion_requires_confirmation,
      :promotion_eligibility_field
    )
  end

  def preview_time
    params[:at].present? ? Time.iso8601(params[:at]) : Time.current
  end

  def preview_promotion_eligible
    ActiveModel::Type::Boolean.new.cast(params[:promotion_eligible]) if params.key?(:promotion_eligible)
  end

  def rule_params
    rules = params.require(:offer).fetch(:rules, [])
    return rules unless rules.is_a?(Array)

    rules.map do |rule|
      next rule unless rule.is_a?(ActionController::Parameters)

      value = rule[:value]
      value = value.permit(:amount, :currency).to_h if value.is_a?(ActionController::Parameters)
      rule.permit(:kind, :dimension, :field, :operator, :score_delta, :forced_outcome, :priority, :enabled).to_h.merge('value' => value)
    end
  end

  def requirement_group_params
    groups = params.require(:offer).fetch(:requirement_groups, [])
    if groups.is_a?(Array)
      groups.map { |group| group.respond_to?(:to_unsafe_h) ? group.to_unsafe_h : group }
    else
      groups
    end
  end
end
