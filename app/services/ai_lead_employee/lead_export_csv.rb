# frozen_string_literal: true

require 'csv'

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

  def each_line
    return enum_for(__method__) unless block_given?

    with_export_snapshot do
      membership = AccountUser.includes(:account, :user).find_by!(account_id: account_id, user_id: user_id)
      raise Pundit::NotAuthorizedError unless membership.administrator?

      directory = AiLeadEmployee::LeadsDirectoryService.new(
        account: membership.account,
        user: membership.user,
        params: params
      )

      yield CSV.generate_line(COLUMNS)
      directory.each_export_row { |row| yield CSV.generate_line(csv_row(row)) }
    end
  end

  private

  attr_reader :account_id, :user_id, :params

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
