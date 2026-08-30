# frozen_string_literal: true

class AiLeadEmployee::HandoffAlertTemplateParams
  def initialize(account:, conversation:, qualification:, alert_type:, booking: nil)
    @account = account
    @conversation = conversation
    @qualification = qualification
    @alert_type = alert_type
    @booking = booking
  end

  def to_h
    return if template.blank?

    template.deep_dup.tap do |params|
      params['processed_params'] = params.fetch('processed_params', {}).deep_merge('body' => alert_template_context)
    end
  end

  private

  attr_reader :account, :conversation, :qualification, :alert_type, :booking

  def template
    @template ||= account.settings&.dig('ai_lead_employee', 'alert_templates', alert_type)
  end

  def alert_template_context
    evidence = qualification.evidence_snapshot

    {
      'conversation_url' => conversation_url,
      'contact' => "#{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      'business_type' => value_for(evidence, 'business_type'),
      'problem' => value_for(evidence, 'problem'),
      'lead_volume' => value_for(evidence, 'lead_volume'),
      'urgency' => value_for(evidence, 'urgency'),
      'budget' => value_for(evidence, 'budget'),
      'decision_authority' => value_for(evidence, 'decision_authority'),
      'qualification_reasons' => qualification.reasons.join('; ')
    }.merge(booking_template_context)
  end

  def booking_template_context
    return {} if booking.blank?

    {
      'booking_time' => booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z'),
      'booking_timezone' => booking.timezone,
      'booking_calendar_id' => booking.calendar_id
    }
  end

  def value_for(evidence, signal)
    evidence.dig(signal, 'value').presence || 'Not provided'
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    return path if base_url.blank?

    "#{base_url.delete_suffix('/')}#{path}"
  end
end
