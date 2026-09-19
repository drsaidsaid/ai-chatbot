# frozen_string_literal: true

class Api::V1::Accounts::BusinessSetupSourcesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :offer
  before_action :source, only: [:show, :update, :publish]

  def index
    render json: offer.business_setup_sources.order(updated_at: :desc).map(&:payload)
  end

  def show
    render json: source.payload
  end

  def create
    record = build_source_record
    record.proposal = new_source_proposal(record)
    record.initialize_history!(editor: Current.user)
    record.save!
    render json: record.payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    source.replace_proposal!(attributes: source_attributes,
                             expected_source_version: params.require(:expected_source_version), editor: Current.user)
    render json: source.payload
  rescue AiLeadEmployee::BusinessSetupSource::Conflict => e
    render json: { error: e.message }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def publish
    source.publish!(expected_source_version: params.require(:expected_source_version),
                    expected_offer_version: params.require(:expected_offer_version), editor: Current.user)
    render json: source.reload.payload
  rescue AiLeadEmployee::BusinessSetupSource::Conflict => e
    render json: { error: e.message }, status: :conflict
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid, ArgumentError, KeyError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  rescue_from AiLeadEmployee::BusinessSetupSource::NotAuthorized do |error|
    render json: { error: error.message }, status: :forbidden
  end

  def offer
    @offer ||= current_account.qualification_offers.find(params[:qualification_offer_id])
  end

  def source
    @source ||= offer.business_setup_sources.find(params[:id])
  end

  def source_params
    params.require(:source).permit(:title, :source_type, :body, reviewed_configuration: {})
  end

  def source_attributes
    @source_attributes ||= source_params.to_h.symbolize_keys
  end

  def build_source_record
    offer.business_setup_sources.new(source_attributes.except(:reviewed_configuration).merge(account: current_account))
  end

  def new_source_proposal(record)
    proposal_for(record, source_attributes[:reviewed_configuration] || offer.payload,
                 previous_proposal: latest_published_source&.proposal)
  end

  def proposal_for(record, reviewed_configuration, previous_proposal: nil)
    AiLeadEmployee::BusinessSetupProposalExtractor.new(
      offer: offer, body: record.body, reviewed_configuration: reviewed_configuration, previous_proposal: previous_proposal
    ).perform
  end

  def latest_published_source
    offer.business_setup_sources.published.order(published_at: :desc, id: :desc).first
  end
end
