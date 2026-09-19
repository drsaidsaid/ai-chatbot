# frozen_string_literal: true

class Api::V1::Accounts::AlertConfigurationsController < Api::V1::Accounts::BaseController
  ALERT_TYPES = %w[
    highly_qualified_sales_handoff
    booking_preparation
    human_review_request
    knowledge_approval
  ].freeze
  ROUTE_TYPES = %w[assignee admin member whatsapp].freeze

  before_action :check_admin_authorization?

  def show
    render json: payload
  end

  def update
    current_account.transaction do
      validate_default_owner!
      validate_alert_routes!
      current_account.update!(settings: merged_settings)
    end
    render json: payload
  rescue ActionController::BadRequest => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def payload
    settings = ai_lead_employee_settings
    {
      default_owner: user_payload(default_owner),
      team_members: current_account.users.order(:name, :id).filter_map { |user| user_payload(user) },
      alert_routes: normalized_routes(settings['alert_routes'])
    }
  end

  def merged_settings
    current_account.settings.to_h.deep_merge(
      'ai_lead_employee' => ai_lead_employee_settings.merge(
        'human_operator_id' => default_owner_id,
        'alert_routes' => normalized_routes(alert_routes)
      )
    )
  end

  def ai_lead_employee_settings
    current_account.settings.to_h.fetch('ai_lead_employee', {}).deep_stringify_keys
  end

  def default_owner
    current_account.users.find_by(id: ai_lead_employee_settings['human_operator_id'])
  end

  def default_owner_id
    return ai_lead_employee_settings['human_operator_id'] unless params.key?(:default_owner_id)

    params[:default_owner_id].presence&.to_i
  end

  def alert_routes
    return ai_lead_employee_settings['alert_routes'] unless params.key?(:alert_routes)

    value = params[:alert_routes]
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
  end

  def normalized_routes(routes)
    routes.to_h.slice(*ALERT_TYPES).transform_values do |values|
      Array(values).map { |route| route.to_h.slice('type', 'user_id', 'recipient').compact.deep_stringify_keys }
    end
  end

  def validate_default_owner!
    return if default_owner_id.blank?
    return if current_account.users.exists?(id: default_owner_id)

    raise ActionController::BadRequest, 'Default owner must belong to this Business Account'
  end

  def validate_alert_routes!
    routes = alert_routes.to_h.deep_stringify_keys
    unknown_types = routes.keys - ALERT_TYPES
    raise ActionController::BadRequest, 'Unsupported alert type' if unknown_types.present?

    routes.each_value { |values| Array(values).each { |route| validate_route!(route.to_h.deep_stringify_keys) } }
  end

  def validate_route!(route)
    raise ActionController::BadRequest, 'Unsupported alert route' unless ROUTE_TYPES.include?(route['type'])

    case route['type']
    when 'member'
      validate_member_route!(route)
    when 'whatsapp'
      validate_whatsapp_route!(route)
    end
  end

  def validate_member_route!(route)
    return if current_account.users.exists?(id: route['user_id'])

    raise ActionController::BadRequest, 'Alert recipient must belong to this Business Account'
  end

  def validate_whatsapp_route!(route)
    recipient = Whatsapp::RecipientIdentifier.normalize(route['recipient'])
    raise ActionController::BadRequest, 'Alert recipient is invalid' if recipient.blank?

    belongs_to_member = current_account.users.any? do |user|
      Whatsapp::RecipientIdentifier.normalize(user.custom_attributes['whatsapp_alert_phone']) == recipient
    end
    raise ActionController::BadRequest, 'Alert recipient must be a current Business Account member' unless belongs_to_member
  end

  def user_payload(user)
    return if user.blank?

    { id: user.id, name: user.name, phone_configured: user.custom_attributes['whatsapp_alert_phone'].present? }
  end
end
