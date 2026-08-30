# frozen_string_literal: true

require 'open3'
require 'json'

class AiLeadEmployee::LaunchProofReport
  CANONICAL_WEBHOOK_PATH = '/webhooks/whatsapp/:phone_number'
  RETIRED_WEBHOOK_PATH = '/webhooks/meta/whatsapp'
  HUMAN_VERIFICATION_PATH = [
    'Configure the Meta test number callback URL to /webhooks/whatsapp/:phone_number for the Channel::Whatsapp phone number.',
    'Send a text message from the Meta test recipient to the configured test number.',
    'Confirm the owned inbox shows the Lead, Conversation, Inbound Message, visible Channel Greeting, and AI Employee Outbound Message.',
    'Confirm the Outbound Message stores Meta message id and sent, delivered, read, or failed status webhooks reconcile onto that Message.',
    'Leave /webhooks/meta/whatsapp configured nowhere; it must continue to return 410 Gone.'
  ].freeze

  def initialize(attributes)
    @account = attributes.fetch(:account)
    @whatsapp_channel = attributes.fetch(:whatsapp_channel)
    @knowledge_items = attributes.fetch(:knowledge_items)
    @orchestration_intent = attributes.fetch(:orchestration_intent)
    @deterministic_checks = attributes.fetch(:deterministic_checks)
    @remaining_blockers = attributes.fetch(:remaining_blockers, [])
    @test_number = attributes.fetch(:test_number, ENV.fetch('META_WHATSAPP_TEST_NUMBER', nil))
    @tested_code_version = attributes[:tested_code_version]
  end

  def to_h
    report_identity.merge(
      proof: 'end_to_end_canonical_launch_proof',
      provider_model: provider_model,
      test_number: test_number,
      test_number_status: test_number.present? ? 'configured' : 'absent',
      configuration_versions: configuration_versions,
      knowledge_versions: knowledge_versions,
      source_references: orchestration_intent.source_references,
      deterministic_checks: deterministic_checks,
      remaining_blockers: remaining_blockers,
      human_verification_path: HUMAN_VERIFICATION_PATH
    )
  end

  def to_markdown
    report = to_h
    <<~MARKDOWN
      # End-to-End Canonical Launch Proof

      - Proof: #{report[:proof]}
      - Tested at: #{report[:tested_at]}
      - Tested code version: #{report[:tested_code_version]}
      - Canonical webhook path: #{report[:canonical_webhook_path]}
      - Retired webhook path: #{report[:retired_webhook_path]}
      - Provider model: #{report[:provider_model]}
      - Test number: #{report[:test_number] || 'not configured'}
      - Test number status: #{report[:test_number_status]}

      ## Configuration Versions
      #{markdown_json(report[:configuration_versions])}

      ## Knowledge Versions
      #{markdown_json(report[:knowledge_versions])}

      ## Source References
      #{markdown_json(report[:source_references])}

      ## Deterministic Checks
      #{markdown_list(report[:deterministic_checks])}

      ## Remaining Blockers
      #{markdown_list(report[:remaining_blockers])}

      ## Human Verification Path
      #{markdown_list(report[:human_verification_path])}
    MARKDOWN
  end

  private

  attr_reader :account, :whatsapp_channel, :knowledge_items, :orchestration_intent, :deterministic_checks, :remaining_blockers,
              :test_number

  def report_identity
    {
      tested_at: Time.current.utc.iso8601,
      tested_code_version: tested_code_version,
      canonical_webhook_path: CANONICAL_WEBHOOK_PATH,
      retired_webhook_path: RETIRED_WEBHOOK_PATH,
      business_account_id: account.id,
      lead_conversation_id: orchestration_intent.conversation_id,
      orchestration_intent_id: orchestration_intent.id,
      outbound_message_id: orchestration_intent.outbound_message_id
    }
  end

  def tested_code_version
    @tested_code_version.presence || env_code_version || git_code_version || raise(ArgumentError, 'tested_code_version is required')
  end

  def env_code_version
    ENV['GIT_SHA'].presence || ENV['SOURCE_VERSION'].presence || ENV['RENDER_GIT_COMMIT'].presence || ENV['VERCEL_GIT_COMMIT_SHA'].presence
  end

  def git_code_version
    return unless Rails.root.join('.git').exist?

    stdout, status = Open3.capture2('git', 'rev-parse', 'HEAD', chdir: Rails.root.to_s)
    return unless status.success?

    stdout.strip.presence
  rescue StandardError
    nil
  end

  def provider_model
    orchestration_intent.model.presence || account.ai_provider_connection&.model
  end

  def configuration_versions
    {
      whatsapp_channel: {
        id: whatsapp_channel.id,
        inbox_id: whatsapp_channel.inbox.id,
        provider: whatsapp_channel.provider,
        phone_number_id: whatsapp_channel.provider_config['phone_number_id'],
        updated_at: whatsapp_channel.updated_at.iso8601,
        sender: 'Whatsapp::SendOnWhatsappService'
      },
      ai_provider_connection: ai_provider_connection_version
    }
  end

  def ai_provider_connection_version
    connection = account.ai_provider_connection
    return { status: 'absent', updated_at: nil } if connection.blank?

    {
      id: connection.id,
      provider: connection.provider,
      model: connection.model,
      status: connection.status,
      updated_at: connection.updated_at.iso8601
    }
  end

  def knowledge_versions
    knowledge_items.map do |item|
      {
        id: item.id,
        title: item.title,
        source_kind: item.source_kind,
        status: item.status,
        approved_at: item.approved_at&.iso8601,
        updated_at: item.updated_at.iso8601,
        source_reference: item.source_reference
      }
    end
  end

  def markdown_list(values)
    values.presence&.map { |value| "- #{value}" }&.join("\n") || '- None'
  end

  def markdown_json(value)
    <<~MARKDOWN.chomp
      ```json
      #{JSON.pretty_generate(value)}
      ```
    MARKDOWN
  end
end
