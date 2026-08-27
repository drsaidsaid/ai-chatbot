# frozen_string_literal: true

require 'csv'

class Api::V1::Accounts::LeadsController < Api::V1::Accounts::BaseController
  EXPORT_COLUMNS = %w[
    id name phone_number email business_name quality score source assignee
    last_contact_at next_action booking_status
  ].freeze

  before_action -> { check_authorization(Contact) }
  before_action :set_contact, only: [:show, :update]

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

  def import
    return render json: { error_key: 'select_csv_file' }, status: :unprocessable_entity if params[:import_file].blank?

    render json: { import: import_payload }
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
    return current_account.contacts.resolved_contacts(use_crm_v2: current_account.feature_enabled?('crm_v2')) if administrator?

    current_account.contacts.where(id: visible_conversations.select(:contact_id))
  end

  def accessible_conversations
    return current_account.conversations if administrator?

    visible_conversations
  end

  def visible_conversations
    scope = current_account.conversations
    inbox_ids = Current.user.inboxes.where(account: current_account).select(:id)
    team_ids = Current.user.teams.where(account: current_account).select(:id)

    scope.where(assignee_id: Current.user.id)
         .or(scope.where(inbox_id: inbox_ids))
         .or(scope.where(team_id: team_ids))
  end

  def administrator?
    current_account.account_users.find_by(user: Current.user)&.administrator?
  end

  def import_payload
    result = { imported_count: 0, failures: [] }

    CSV.foreach(params[:import_file].path, headers: true).with_index(2) do |row, line_number|
      import_row(row)
      result[:imported_count] += 1
    rescue ActiveRecord::RecordInvalid => e
      result[:failures] << { line: line_number, error: e.record.errors.full_messages.to_sentence }
    end

    completed_import_payload(result)
  rescue CSV::MalformedCSVError => e
    failed_import_payload(e.message)
  end

  def completed_import_payload(result)
    {
      status: result[:failures].present? ? 'partial' : 'completed',
      imported_count: result[:imported_count],
      failed_count: result[:failures].size,
      failures: result[:failures]
    }
  end

  def failed_import_payload(message)
    {
      status: 'failed',
      imported_count: 0,
      failed_count: 1,
      failures: [{ line: nil, error: message }]
    }
  end

  def import_row(row)
    name = row['name'].presence || row['lead'].presence
    phone_number = row['phone_number'].presence || row['phone'].presence
    email = row['email'].presence
    business_name = row['business_name'].presence || row['company_name'].presence || row['business'].presence
    contact = import_contact_for(phone_number, email)
    contact.assign_attributes(name: name, email: email)
    contact.additional_attributes = (contact.additional_attributes || {}).merge('company_name' => business_name).compact
    contact.save!
  end

  def import_contact_for(phone_number, email)
    return current_account.contacts.find_or_initialize_by(phone_number: phone_number) if phone_number.present?
    return current_account.contacts.find_or_initialize_by(email: email) if email.present?

    current_account.contacts.new
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
