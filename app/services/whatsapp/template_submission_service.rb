# frozen_string_literal: true

# Owns the Meta template submission state machine. A transport timeout is deliberately
# unknown: it is reconciled by reading Meta, never retried by creating a second template.
class Whatsapp::TemplateSubmissionService
  def initialize(revision:)
    @revision = revision
  end

  def perform(reconcile: false)
    return reconcile! if reconcile
    return unless claim_submission!

    response = HTTParty.post(endpoint, headers: headers, body: request_body.to_json, timeout: 10)
    return unknown! unless response.success?

    provider_id = response_payload(response)['id']
    return unknown! if provider_id.blank?

    @revision.update!(provider_template_id: provider_id, status: :submitted, status_synced_at: Time.current)
  rescue Timeout::Error
    unknown!
  end

  private

  def reconcile!
    response = HTTParty.get("#{endpoint}?name=#{CGI.escape(@revision.whatsapp_template.name)}", headers: headers, timeout: 10)
    return unknown! unless response.success?

    provider = Array(response_payload(response)['data']).find { |item| item['name'] == @revision.whatsapp_template.name }
    return unknown! unless provider

    status = provider['status'].to_s.downcase
    mapped_status = { 'approved' => :approved, 'rejected' => :rejected, 'paused' => :paused, 'disabled' => :disabled }.fetch(status, :submitted)
    @revision.update!(provider_template_id: provider['id'], status: mapped_status, rejection_reason: provider['rejected_reason'],
                      status_synced_at: Time.current)
  rescue Timeout::Error
    unknown!
  end

  def unknown!
    @revision.update!(status: :unknown, status_synced_at: Time.current) unless @revision.unknown?
  end

  def claim_submission!
    @revision.with_lock do
      @revision.reload
      next false unless @revision.submission_pending?

      @revision.update!(status: :submitting)
      true
    end
  end

  def response_payload(response)
    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end

  def endpoint
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/v14.0/#{@revision.channel.provider_config.fetch('business_account_id')}/message_templates"
  end

  def headers
    { 'Authorization' => "Bearer #{@revision.channel.template_access_token}", 'Content-Type' => 'application/json',
      'Idempotency-Key' => @revision.submission_key }
  end

  def request_body
    {
      name: @revision.whatsapp_template.name, language: @revision.language, category: @revision.category,
      components: [{ type: 'BODY', text: @revision.body }]
    }.tap do |payload|
      payload[:components] << @revision.media.merge(type: 'HEADER') if @revision.media.present?
      payload[:components] << { type: 'BUTTONS', buttons: @revision.buttons } if @revision.buttons.present?
    end
  end
end
