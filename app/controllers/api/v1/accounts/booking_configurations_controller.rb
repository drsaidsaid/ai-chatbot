# frozen_string_literal: true

class Api::V1::Accounts::BookingConfigurationsController < Api::V1::Accounts::BaseController
  BOOLEAN_VALUES = [true, false].freeze
  before_action :check_admin_authorization?

  def show
    render json: configuration_payload
  end

  def update
    validate_booking_params!
    current_account.transaction do
      current_account.update!(settings: merged_settings)
      current_account.google_calendar_connection&.update!(calendar_id: booking_params[:calendar_id]) if booking_params[:calendar_id].present?
    end
    render json: configuration_payload
  end

  private

  def merged_settings
    current_account.settings.to_h.deep_merge(
      'ai_lead_employee' => {
        'booking' => booking_params.to_h
      }
    )
  end

  def booking_params
    params.permit(
      :calendar_id,
      :timezone,
      :duration_minutes,
      :buffer_before_minutes,
      :buffer_after_minutes,
      :minimum_notice_minutes,
      working_days: [],
      allowed_hours: [:start, :end],
      exceptions: [:date, :unavailable]
    )
  end

  def configuration_payload
    AiLeadEmployee::BookingConfiguration.for(current_account).merge(
      'connection' => current_account.google_calendar_connection&.public_payload
    )
  end

  def validate_booking_params! # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    calendar_id = booking_params[:calendar_id]
    if booking_params.key?(:calendar_id) && (calendar_id.blank? || calendar_id.to_s.length > 255)
      raise ActionController::BadRequest, 'Invalid calendar ID'
    end

    timezone = booking_params[:timezone]
    raise ActionController::BadRequest, 'Invalid timezone' if booking_params.key?(:timezone) && ActiveSupport::TimeZone[timezone].blank?

    days = Array(booking_params[:working_days]).map { |day| Integer(day, exception: false) }
    unless days.none?(&:nil?) && days.uniq.length == days.length && days.all? { |day| day.between?(0, 6) }
      raise ActionController::BadRequest, 'Invalid working days'
    end

    validate_integer!(:duration_minutes, 5..480)
    validate_integer!(:buffer_before_minutes, 0..1440)
    validate_integer!(:buffer_after_minutes, 0..1440)
    validate_integer!(:minimum_notice_minutes, 0..43_200)
    validate_exceptions!
    return if booking_params[:allowed_hours].blank?

    start_time = booking_params.dig(:allowed_hours, :start).to_s
    end_time = booking_params.dig(:allowed_hours, :end).to_s
    format = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/
    raise ActionController::BadRequest, 'Invalid allowed hours' unless start_time.match?(format) && end_time.match?(format) && start_time < end_time
  end

  def validate_integer!(key, range)
    return if booking_params[key].blank?

    value = Integer(booking_params[key], exception: false)
    raise ActionController::BadRequest, "Invalid #{key}" unless value && range.cover?(value)
  end

  def validate_exceptions!
    exceptions = Array(booking_params[:exceptions])
    dates = exceptions.map { |exception| exception[:date].to_s }
    valid = dates.uniq.length == dates.length && exceptions.all? do |exception|
      Date.iso8601(exception[:date].to_s)
      BOOLEAN_VALUES.include?(exception[:unavailable])
    rescue Date::Error
      false
    end
    raise ActionController::BadRequest, 'Invalid booking exceptions' unless valid
  end
end
