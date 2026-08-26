# frozen_string_literal: true

class Api::V1::Accounts::BookingConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: configuration_payload
  end

  def update
    current_account.update!(settings: merged_settings)
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
      :provider,
      :calendar_id,
      :connected,
      :timezone,
      :duration_minutes,
      :buffer_before_minutes,
      :buffer_after_minutes,
      :minimum_notice_minutes,
      working_days: [],
      allowed_hours: [:start, :end],
      busy_slots: [:start, :end]
    )
  end

  def configuration_payload
    AiLeadEmployee::BookingConfiguration.for(current_account)
  end
end
