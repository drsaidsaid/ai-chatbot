# frozen_string_literal: true

# Owns the Meta template submission state machine. A transport timeout is deliberately
# unknown: it is reconciled by reading Meta, never retried by creating a second template.
class Whatsapp::TemplateSubmissionService
  TRANSPORT_ERRORS = [Timeout::Error, SocketError, OpenSSL::SSL::SSLError, EOFError, Errno::ECONNREFUSED, Errno::ECONNRESET,
                      Errno::EHOSTUNREACH, Errno::ETIMEDOUT].freeze

  def initialize(revision:)
    @revision = revision
  end

  def perform(reconcile: false)
    return reconcile! if reconcile
    return unless claim_submission!

    response = HTTParty.post(submission_endpoint, headers: headers, body: submission_body.to_json, timeout: 10)
    return handle_unsuccessful_submission!(response) unless response.success?

    provider_id = response_payload(response)['id'].presence || edit_target_id
    return unknown! if provider_id.blank?

    @revision.update!(provider_template_id: provider_id, status: :submitted, rejection_reason: nil, submission_failure: {},
                      status_synced_at: Time.current)
  rescue *TRANSPORT_ERRORS
    unknown!(failure: failure_payload(kind: 'transport_unknown', message: 'Provider connection failed; reconcile before retrying.'))
  end

  private

  def reconcile!
    response = HTTParty.get("#{endpoint}?name=#{CGI.escape(@revision.whatsapp_template.name)}", headers: headers, timeout: 10)
    unless response.success?
      return unknown!(failure: failure_payload(kind: 'reconciliation_unavailable', message: 'Provider status could not be read.',
                                               response: response))
    end

    provider = Array(response_payload(response)['data']).find { |item| provider_matches_revision?(item) }
    return unknown! unless provider

    status = provider['status'].to_s.downcase
    mapped_status = { 'approved' => :approved, 'rejected' => :rejected, 'paused' => :paused, 'disabled' => :disabled }.fetch(status, :submitted)
    @revision.update!(provider_template_id: provider['id'], status: mapped_status, rejection_reason: provider['rejected_reason'],
                      submission_failure: {}, status_synced_at: Time.current)
  rescue *TRANSPORT_ERRORS
    unknown!(failure: failure_payload(kind: 'reconciliation_unavailable', message: 'Provider status could not be read.'))
  end

  def unknown!(failure: nil)
    @revision.update!(status: :unknown, rejection_reason: nil, submission_failure: failure || {}, status_synced_at: Time.current)
  end

  def handle_unsuccessful_submission!(response)
    unless response.code.to_i.between?(400, 499)
      return unknown!(failure: failure_payload(kind: 'provider_unavailable',
                                               message: 'Provider submission was unavailable; reconcile before retrying.',
                                               response: response))
    end
    error = response_payload(response)['error'].to_h
    kind = case response.code.to_i
           when 401, 403 then 'authentication'
           when 429 then 'throttled'
           else 'request_rejected'
           end
    message = error['message'].presence || 'Provider did not accept the template submission.'
    @revision.update!(status: :submission_failed, rejection_reason: nil,
                      submission_failure: failure_payload(kind: kind, message: message, response: response,
                                                          provider_code: error['code']),
                      status_synced_at: Time.current)
  end

  def failure_payload(kind:, message:, response: nil, provider_code: nil)
    { 'kind' => kind, 'message' => message.to_s.first(500), 'http_status' => response&.code&.to_i,
      'provider_code' => provider_code, 'observed_at' => Time.current.iso8601 }.compact
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

  def provider_matches_revision?(provider)
    provider_identity_matches?(provider) &&
      provider['name'] == @revision.whatsapp_template.name &&
      provider['language'] == @revision.language &&
      provider['category'] == @revision.category &&
      semantic_components(provider['components']) == semantic_components(request_body[:components])
  end

  def provider_identity_matches?(provider)
    expected_id = @revision.provider_template_id.presence || edit_target_id
    expected_id.blank? || provider['id'] == expected_id
  end

  def semantic_components(components)
    Array(components).map do |component|
      item = component.to_h.stringify_keys
      case item['type']
      when 'BODY'
        item.slice('type', 'text')
      when 'HEADER'
        item.slice('type', 'format', 'text')
      when 'BUTTONS'
        { 'type' => 'BUTTONS', 'buttons' => Array(item['buttons']).map { |button| semantic_button(button) } }
      else
        item.except('example')
      end
    end
  end

  def semantic_button(button)
    attributes = button.to_h.stringify_keys
    allowed_fields = case attributes['type']
                     when 'URL' then %w[type text url]
                     when 'PHONE_NUMBER' then %w[type text phone_number]
                     else %w[type text]
                     end
    attributes.slice(*allowed_fields).compact_blank
  end

  def endpoint
    "#{api_root}/#{@revision.channel.provider_config.fetch('business_account_id')}/message_templates"
  end

  def submission_endpoint
    edit_target_id.present? ? "#{api_root}/#{edit_target_id}" : endpoint
  end

  def api_root
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    "#{base}/#{version}"
  end

  def edit_target_id
    previous_revisions = @revision.whatsapp_template.revisions.where('revision_number < ?', @revision.revision_number)
    @edit_target_id ||= previous_revisions.where.not(provider_template_id: [nil, ''])
                                          .order(revision_number: :desc)
                                          .pick(:provider_template_id)
  end

  def headers
    { 'Authorization' => "Bearer #{@revision.channel.template_access_token}", 'Content-Type' => 'application/json',
      'Idempotency-Key' => @revision.submission_key }
  end

  def request_body
    {
      name: @revision.whatsapp_template.name, language: @revision.language, category: @revision.category,
      components: [body_component]
    }.tap do |payload|
      payload[:components] << @revision.media.merge(type: 'HEADER') if @revision.media.present?
      payload[:components] << { type: 'BUTTONS', buttons: @revision.buttons.map { |button| button.to_h.compact_blank } } if @revision.buttons.present?
    end
  end

  def submission_body
    return request_body if edit_target_id.blank?

    request_body.slice(:category, :components)
  end

  def body_component
    component = { type: 'BODY', text: @revision.body }
    examples = Array(@revision.variables).sort_by { |variable| variable['position'].to_i }.pluck('example')
    component[:example] = { body_text: [examples] } if examples.present?
    component
  end
end
