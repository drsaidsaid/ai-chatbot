# frozen_string_literal: true

require 'csv'

class Api::V1::Accounts::LeadsController < Api::V1::Accounts::BaseController
  EXPORT_COLUMNS = %w[
    id name phone_number email business_name quality score source assignee
    last_contact_at next_action booking_status
  ].freeze

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
    send_data export_csv,
              filename: "leads-#{Time.zone.today.iso8601}.csv",
              type: 'text/csv'
  end

  private

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

  def export_csv
    CSV.generate(headers: true) do |csv|
      csv << EXPORT_COLUMNS
      export_rows.each { |row| csv << export_row(row) }
    end
  end

  def export_rows
    AiLeadEmployee::LeadsDirectoryService.new(
      account: current_account,
      user: Current.user,
      params: lead_directory_params.merge(page: 1, per_page: 100)
    ).export_rows
  end

  def export_row(row)
    [
      row[:id],
      row[:name],
      row[:phone_number],
      row[:email],
      row[:business_name],
      row[:quality],
      row[:score],
      row.dig(:source, :name),
      row.dig(:assignee, :name),
      row[:last_contact_at],
      row.dig(:next_action, :key),
      row.dig(:booking, :status)
    ]
  end
end
