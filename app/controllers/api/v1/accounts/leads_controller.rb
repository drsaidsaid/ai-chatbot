# frozen_string_literal: true

require 'csv'

class Api::V1::Accounts::LeadsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Contact) }
  before_action :set_contact, only: [:show, :update, :reconsent]

  def index
    render json: directory_payload
  end

  def show
    render json: directory_payload(lead_id: @contact.id)[:selected_lead]
  end

  def update
    AiLeadEmployee::LeadUpdateService.new(
      account: current_account,
      user: Current.user,
      contact: @contact,
      conversation_scope: accessible_conversations,
      attributes: lead_update_params
    ).perform

    render json: directory_payload(lead_id: @contact.id)[:selected_lead]
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def reconsent
    AiLeadEmployee::AutomatedContactConsent.grant!(
      contact: @contact,
      source_message: current_account.messages.find(params.require(:source_message_id)),
      expected_event_id: params.require(:expected_event_id),
      actor: Current.user
    )

    render json: directory_payload(lead_id: @contact.id)[:selected_lead]
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def import
    return render json: { error_key: 'select_csv_file' }, status: :unprocessable_entity if params[:import_file].blank?

    result = AiLeadEmployee::LeadImportService.new(
      account: current_account,
      user: Current.user,
      file: params[:import_file],
      mode: params[:mode],
      preview_digest: params[:preview_digest]
    ).perform
    render json: { import: result }
  rescue AiLeadEmployee::LeadImportService::ImportError => e
    render json: { error_key: e.error_key }, status: :unprocessable_entity
  end

  def export
    artifact = AiLeadEmployee::LeadExportCsv.new(
      account_id: current_account.id,
      user_id: Current.user.id,
      params: lead_directory_params.to_h
    ).build
    prepare_export_response(artifact)
  end

  private

  def prepare_export_response(artifact)
    request.env[Rack::RACK_TEMPFILES] ||= []
    request.env[Rack::RACK_TEMPFILES] << artifact
    request.env[AiLeadEmployee::LeadExportBodyMiddleware::ENV_KEY] = artifact
    response.headers['Cache-Control'] = 'private, no-store'
    send_file artifact.path,
              filename: "leads-#{Time.zone.today.iso8601}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  def directory_payload(extra_params = {})
    AiLeadEmployee::LeadsDirectoryService.new(
      account: current_account,
      user: Current.user,
      params: lead_directory_params.merge(extra_params)
    ).perform
  end

  def lead_directory_params
    params.permit(
      :q, :quality, :follow_up_state, :assignee_id, :source_id,
      :booking_status, :page, :per_page, :sort, :direction, :lead_id
    )
  end

  def lead_update_params
    params.require(:lead).permit(
      :name,
      :phone_number,
      :email,
      :business_name,
      :city,
      :country,
      :assignee_id,
      evidence: {}
    )
  end

  def set_contact
    @contact = accessible_contacts.find(params[:id])
  end

  def accessible_contacts
    policy_scope(current_account.contacts)
  end

  def accessible_conversations
    policy_scope(current_account.conversations)
  end

  def visible_conversations
    accessible_conversations
  end

  def administrator?
    current_account.account_users.find_by(user: Current.user)&.administrator?
  end
end
