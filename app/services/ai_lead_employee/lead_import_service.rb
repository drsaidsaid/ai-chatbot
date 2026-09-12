# frozen_string_literal: true

require 'csv'
require 'digest'

# rubocop:disable Metrics/ClassLength -- preview, bounded apply, and shared row normalization must use one resolution contract
class AiLeadEmployee::LeadImportService
  MAX_FILE_BYTES = 5.megabytes
  MAX_ROWS = 100
  LOCK_WAIT = 1.second
  APPLY_DEADLINE = 5.seconds
  class ImportError < StandardError
    attr_reader :error_key

    def initialize(error_key)
      @error_key = error_key
      super(error_key)
    end
  end

  class ImportDeadlineExceeded < StandardError; end

  def initialize(account:, user:, file:, mode: 'preview', preview_digest: nil)
    @account = account
    @user = user
    @file = file
    @mode = mode.to_s.presence || 'preview'
    @preview_digest = preview_digest.to_s
  end

  def perform
    raise Pundit::NotAuthorizedError unless access.administrator?

    content = read_content
    return preview_payload(content).except(:fingerprint) unless mode == 'apply'

    apply_content!(content)
  rescue CSV::MalformedCSVError
    invalid_file_payload('CSV could not be parsed')
  end

  private

  attr_reader :account, :user, :file, :mode, :preview_digest

  def access
    @access ||= AiLeadEmployee::AccessScope.new(account: account, user: user)
  end

  def read_content
    file.rewind if file.respond_to?(:rewind)
    content = file.read.to_s.b
    raise ImportError, 'import_file_too_large' if content.bytesize > MAX_FILE_BYTES

    content.force_encoding(Encoding::UTF_8)
    raise ImportError, 'import_invalid_encoding' unless content.valid_encoding? && content.exclude?("\u0000")

    content.delete_prefix("\uFEFF")
  end

  def preview_payload(content)
    table = import_table(content)
    rows = table.each_with_index.map { |row, index| preview_row(row, index + 2) }
    mark_duplicate_file_identities!(rows)
    preview_summary(rows, preview_digest_for(content, rows))
  end

  def import_table(content)
    table = CSV.parse(content, headers: true)
    raise ImportError, 'import_missing_headers' if table.headers.blank?
    raise ImportError, 'import_too_many_rows' if table.length > MAX_ROWS

    table
  end

  def preview_summary(rows, digest)
    counts = rows.pluck(:action).tally
    error_count = rows.count { |row| row[:action] == 'error' || row[:action] == 'ambiguous' }

    {
      status: error_count.zero? ? 'ready' : 'invalid',
      digest: signed_preview_digest(digest),
      fingerprint: digest,
      total_count: rows.length,
      create_count: counts.fetch('create', 0),
      update_count: counts.fetch('update', 0),
      error_count: error_count,
      can_apply: rows.any? && error_count.zero?,
      rows: rows.map { |row| row.except(:identity_keys) }
    }
  end

  def preview_digest_for(content, rows)
    resolution = rows.map do |row|
      row.slice(:line, :action, :existing_lead_id, :identity_keys, :errors)
    end
    Digest::SHA256.hexdigest([Digest::SHA256.hexdigest(content), resolution].to_json)
  end

  def preview_row(csv_row, line)
    attributes = normalized_attributes(csv_row)
    matches = identity_matches(attributes)
    errors = validation_errors(attributes)
    action = row_action(matches, errors)
    errors << 'Phone and email identify different existing Leads' if action == 'ambiguous'

    attributes.merge(
      line: line,
      action: action,
      existing_lead_id: matches.one? ? matches.first.id : nil,
      errors: errors,
      identity_keys: identity_keys(attributes)
    )
  end

  def normalized_attributes(row)
    values = row.to_h.transform_keys { |key| key.to_s.strip.downcase }
    {
      name: first_value(values, 'name', 'lead'),
      phone_number: first_value(values, 'phone_number', 'phone'),
      email: first_value(values, 'email')&.downcase,
      business_name: first_value(values, 'business_name', 'company_name', 'business')
    }
  end

  def first_value(values, *keys)
    keys.lazy.map { |key| values[key].to_s.strip.presence }.find(&:present?)
  end

  def identity_matches(attributes)
    matches = []
    matches.concat(account.contacts.where(phone_number: attributes[:phone_number]).to_a) if attributes[:phone_number].present?
    matches.concat(account.contacts.where('LOWER(email) = ?', attributes[:email]).to_a) if attributes[:email].present?
    matches.uniq(&:id)
  end

  def validation_errors(attributes)
    required_errors(attributes) + phone_errors(attributes[:phone_number]) + email_errors(attributes[:email])
  end

  def required_errors(attributes)
    errors = []
    errors << 'Name is required' if attributes[:name].blank?
    errors << 'Phone or email is required' if attributes.values_at(:phone_number, :email).all?(&:blank?)
    errors
  end

  def phone_errors(phone_number)
    return [] if phone_number.blank? || /\A\+[1-9]\d{1,14}\z/.match?(phone_number)

    ['Phone number must use E.164 format']
  end

  def email_errors(email)
    return [] if email.blank? || Devise.email_regexp.match?(email)

    ['Email is invalid']
  end

  def row_action(matches, errors)
    return 'error' if errors.present?
    return 'ambiguous' if matches.many?

    matches.one? ? 'update' : 'create'
  end

  def identity_keys(attributes)
    [
      ("phone:#{attributes[:phone_number]}" if attributes[:phone_number].present?),
      ("email:#{attributes[:email]}" if attributes[:email].present?)
    ].compact
  end

  def mark_duplicate_file_identities!(rows)
    duplicate_keys = rows.flat_map { |row| row[:identity_keys] }.tally.select { |_key, count| count > 1 }.keys
    return if duplicate_keys.empty?

    rows.each do |row|
      next unless row[:identity_keys].intersect?(duplicate_keys)

      row[:action] = 'ambiguous'
      row[:errors] << 'Identity appears more than once in this file'
    end
  end

  def apply!(preview)
    verified_preview = preview_verifier.verified(preview_digest)&.with_indifferent_access
    valid_preview = verified_preview&.slice(:account_id, :user_id, :fingerprint) == {
      account_id: account.id,
      user_id: user.id,
      fingerprint: preview[:fingerprint]
    }.with_indifferent_access
    raise ImportError, 'import_file_changed' unless valid_preview
    raise ImportError, 'import_has_errors' unless preview[:can_apply]

    preview[:rows].each do |row|
      apply_statement_timeout!
      apply_row!(row)
      ensure_apply_deadline!
    end

    preview.except(:fingerprint).merge(status: 'completed', imported_count: preview[:total_count])
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    raise ImportError, 'import_identity_changed'
  end

  def apply_content!(content)
    @apply_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + APPLY_DEADLINE
    ActiveRecord::Base.transaction do
      configure_apply_timeouts!
      ActiveRecord::Base.connection.execute('LOCK TABLE contacts IN ACCESS EXCLUSIVE MODE')
      apply_statement_timeout!
      apply!(preview_payload(content)).tap { ensure_apply_deadline! }
    end
  rescue ImportDeadlineExceeded, ActiveRecord::LockWaitTimeout
    raise ImportError, 'import_retry_later'
  rescue ActiveRecord::StatementInvalid => e
    raise unless retryable_database_timeout?(e)

    raise ImportError, 'import_retry_later'
  end

  def configure_apply_timeouts!
    connection = ActiveRecord::Base.connection
    connection.execute("SET LOCAL lock_timeout = '#{LOCK_WAIT.in_milliseconds.to_i}ms'")
    connection.execute("SET LOCAL statement_timeout = '#{APPLY_DEADLINE.in_milliseconds.to_i}ms'")
  end

  def apply_statement_timeout!
    remaining_ms = ((@apply_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000).floor
    raise ImportDeadlineExceeded if remaining_ms <= 0

    ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = '#{remaining_ms}ms'")
  end

  def ensure_apply_deadline!
    raise ImportDeadlineExceeded if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @apply_deadline
  end

  def retryable_database_timeout?(error)
    error.cause.is_a?(PG::LockNotAvailable) || error.cause.is_a?(PG::QueryCanceled)
  end

  def signed_preview_digest(fingerprint)
    preview_verifier.generate({ account_id: account.id, user_id: user.id, fingerprint: fingerprint }, expires_in: 30.minutes)
  end

  def preview_verifier
    Rails.application.message_verifier('ai_lead_employee_lead_import')
  end

  def apply_row!(row)
    attributes = row.slice(:name, :phone_number, :email, :business_name)
    if row[:action] == 'update'
      contact = account.contacts.find(row[:existing_lead_id])
      AiLeadEmployee::LeadUpdateService.new(account: account, user: user, contact: contact, attributes: attributes).perform
    else
      account.contacts.create!(
        name: attributes[:name],
        phone_number: attributes[:phone_number],
        email: attributes[:email],
        additional_attributes: { 'company_name' => attributes[:business_name] }.compact
      )
    end
  end

  def invalid_file_payload(message)
    {
      status: 'invalid', total_count: 0, create_count: 0, update_count: 0,
      error_count: 1, can_apply: false,
      rows: [{ line: nil, action: 'error', errors: [message] }]
    }
  end
end
# rubocop:enable Metrics/ClassLength
