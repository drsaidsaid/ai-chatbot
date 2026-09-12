# frozen_string_literal: true

require 'csv'
require 'tempfile'

class AiLeadEmployee::LeadExportCsv
  COLUMNS = %w[
    id name phone_number email business_name quality score source assignee
    last_contact_at next_action booking_status
  ].freeze

  def initialize(account_id:, user_id:, params: {})
    @account_id = account_id
    @user_id = user_id
    @params = params.to_h
  end

  def build
    membership = authorized_membership!
    artifact = Tempfile.new(['lead-export-', '.csv'])
    artifact.chmod(0o600)
    with_export_snapshot do
      directory = AiLeadEmployee::LeadsDirectoryService.new(
        account: membership.account,
        user: membership.user,
        params: params
      )
      artifact.write(CSV.generate_line(COLUMNS))
      directory.each_export_row { |row| artifact.write(CSV.generate_line(csv_row(row))) }
    end
    authorized_membership!
    artifact.flush
    artifact.rewind
    artifact
  rescue StandardError
    artifact&.close!
    raise
  end

  private

  attr_reader :account_id, :user_id, :params

  def authorized_membership!
    membership = AccountUser.includes(:account, :user).find_by!(account_id: account_id, user_id: user_id)
    raise Pundit::NotAuthorizedError unless membership.administrator?

    membership
  end

  def with_export_snapshot(&)
    connection = ActiveRecord::Base.connection
    return yield if connection.transaction_open?

    ActiveRecord::Base.transaction(isolation: :repeatable_read, &)
  end

  def csv_row(row)
    [
      row[:id], row[:name], row[:phone_number], row[:email], row[:business_name],
      row[:quality], row[:score], row.dig(:source, :name), row.dig(:assignee, :name),
      row[:last_contact_at], row.dig(:next_action, :key), row.dig(:booking, :status)
    ]
  end
end
