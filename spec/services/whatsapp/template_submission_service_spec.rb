# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::TemplateSubmissionService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider_config: {}, sync_templates: false,
                              validate_provider_config: false).tap do |record|
      record.update_columns(provider: 'whatsapp_cloud', provider_config: { 'business_account_id' => 'waba-r26' }) # rubocop:disable Rails/SkipsModelValidations
    end
  end
  let(:template) { WhatsappTemplate.create!(account: account, channel: channel, created_by: admin, name: 'order_update') }
  let(:revision) do
    WhatsappTemplateRevision.create!(
      whatsapp_template: template, account: account, channel: channel, revision_number: 1,
      language: 'en_US', category: 'UTILITY', body: 'Order ready', submission_key: 'submission-r26',
      content_digest: 'digest', status: :submission_pending, submitted_at: Time.current, submitted_by: admin
    )
  end
  let(:endpoint) { 'https://graph.facebook.com/v22.0/waba-r26/message_templates' }

  it 'claims a pending revision once so duplicate jobs cannot create duplicate Meta templates' do
    create_request = stub_request(:post, endpoint).to_return(
      status: 200, body: { id: 'meta-1' }.to_json, headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(revision: revision).perform
    described_class.new(revision: revision.reload).perform

    expect(create_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'submitted', provider_template_id: 'meta-1')
  end

  it 'submits Meta-compatible component examples and button fields' do
    schema_revision = WhatsappTemplateRevision.create!(
      whatsapp_template: template, account: account, channel: channel, revision_number: 1,
      language: 'en_US', category: 'UTILITY', submission_key: 'submission-schema', content_digest: 'schema-digest',
      status: :submission_pending, submitted_at: Time.current, submitted_by: admin,
      body: 'Hello {{1}}',
      variables: [{ 'position' => 1, 'example' => 'Asha' }],
      media: { 'format' => 'IMAGE', 'example' => { 'header_handle' => ['fake-meta-header-handle'] } },
      buttons: [
        { 'type' => 'QUICK_REPLY', 'text' => 'Thanks', 'url' => '' },
        { 'type' => 'URL', 'text' => 'View order', 'url' => 'https://example.test/orders/{{1}}' },
        { 'type' => 'PHONE_NUMBER', 'text' => 'Call us', 'phone_number' => '+255700000000' }
      ]
    )
    request = stub_request(:post, endpoint).with do |provider_request|
      JSON.parse(provider_request.body) == {
        'name' => 'order_update',
        'language' => 'en_US',
        'category' => 'UTILITY',
        'components' => [
          { 'type' => 'BODY', 'text' => 'Hello {{1}}', 'example' => { 'body_text' => [['Asha']] } },
          { 'type' => 'HEADER', 'format' => 'IMAGE',
            'example' => { 'header_handle' => ['fake-meta-header-handle'] } },
          { 'type' => 'BUTTONS', 'buttons' => [
            { 'type' => 'QUICK_REPLY', 'text' => 'Thanks' },
            { 'type' => 'URL', 'text' => 'View order', 'url' => 'https://example.test/orders/{{1}}' },
            { 'type' => 'PHONE_NUMBER', 'text' => 'Call us', 'phone_number' => '+255700000000' }
          ] }
        ]
      }
    end.to_return(status: 200, body: { id: 'meta-schema' }.to_json, headers: { 'Content-Type' => 'application/json' })

    described_class.new(revision: schema_revision).perform

    expect(request).to have_been_requested.once
  end

  it 'edits the existing Meta template when submitting a new local revision' do
    revision.update!(status: :approved, provider_template_id: 'meta-approved')
    edited_revision = WhatsappTemplateRevision.create!(
      whatsapp_template: template, account: account, channel: channel, revision_number: 2,
      language: 'en_US', category: 'MARKETING', body: 'Order {{1}} is ready',
      variables: [{ 'position' => 1, 'example' => 'A-123' }], submission_key: 'submission-edit-r26',
      content_digest: 'edited-digest', status: :submission_pending, submitted_at: Time.current, submitted_by: admin
    )
    edit_request = stub_request(:post, 'https://graph.facebook.com/v22.0/meta-approved').with do |provider_request|
      JSON.parse(provider_request.body) == {
        'category' => 'MARKETING',
        'components' => [
          { 'type' => 'BODY', 'text' => 'Order {{1}} is ready', 'example' => { 'body_text' => [['A-123']] } }
        ]
      }
    end.to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })

    described_class.new(revision: edited_revision).perform

    expect(edit_request).to have_been_requested.once
    expect(edited_revision.reload).to have_attributes(status: 'submitted', provider_template_id: 'meta-approved')
  end

  it 'reconciles an uncertain edit without retrying the provider mutation' do
    revision.update!(status: :approved, provider_template_id: 'meta-approved')
    edited_revision = WhatsappTemplateRevision.create!(
      whatsapp_template: template, account: account, channel: channel, revision_number: 2,
      language: 'en_US', category: 'UTILITY', body: 'Updated order', submission_key: 'submission-edit-timeout',
      content_digest: 'edited-timeout-digest', status: :submission_pending, submitted_at: Time.current, submitted_by: admin
    )
    edit_request = stub_request(:post, 'https://graph.facebook.com/v22.0/meta-approved').to_timeout
    status_request = stub_request(:get, "#{endpoint}?name=order_update").to_return(
      {
        status: 200,
        body: { data: [{ id: 'meta-approved', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'APPROVED',
                         components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      },
      {
        status: 200,
        body: { data: [{ id: 'meta-approved', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'APPROVED',
                         components: [{ type: 'BODY', text: 'Updated order' }] }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    )

    described_class.new(revision: edited_revision).perform
    described_class.new(revision: edited_revision.reload).perform
    described_class.new(revision: edited_revision.reload).perform(reconcile: true)

    expect(edit_request).to have_been_requested.once
    expect(edited_revision.reload).to have_attributes(status: 'unknown', provider_template_id: nil)
    expect(revision.reload).not_to be_sendable

    described_class.new(revision: edited_revision.reload).perform(reconcile: true)

    expect(status_request).to have_been_requested.times(2)
    expect(edited_revision.reload).to have_attributes(status: 'approved', provider_template_id: 'meta-approved')
  end

  it 'reconciles an uncertain timeout without repeating Meta creation' do
    create_request = stub_request(:post, endpoint).to_timeout
    status_request = stub_request(:get, "#{endpoint}?name=order_update")
                     .to_return(status: 200, body: { data: [{ id: 'meta-2', name: 'order_update', language: 'en_US', category: 'UTILITY',
                                                              status: 'APPROVED',
                                                              components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
                                headers: { 'Content-Type' => 'application/json' })

    described_class.new(revision: revision).perform
    described_class.new(revision: revision.reload).perform
    described_class.new(revision: revision.reload).perform(reconcile: true)

    expect(create_request).to have_been_requested.once
    expect(status_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'approved', provider_template_id: 'meta-2')
  end

  it 'matches reconciliation by name, language, and submitted components instead of attaching an older approval' do
    status_request = stub_request(:get, "#{endpoint}?name=order_update")
                     .to_return(status: 200, body: {
                       data: [
                         { id: 'meta-old', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'APPROVED',
                           components: [{ type: 'BODY', text: 'Old content' }] },
                         { id: 'meta-wrong-language', name: 'order_update', language: 'sw', category: 'UTILITY', status: 'APPROVED',
                           components: [{ type: 'BODY', text: 'Order ready' }] },
                         { id: 'meta-current', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'REJECTED',
                           rejected_reason: 'INVALID_FORMAT', components: [{ type: 'BODY', text: 'Order ready' }] }
                       ]
                     }.to_json, headers: { 'Content-Type' => 'application/json' })
    revision.update!(status: :unknown)

    described_class.new(revision: revision).perform(reconcile: true)

    expect(status_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'rejected', provider_template_id: 'meta-current',
                                               rejection_reason: 'INVALID_FORMAT')
  end

  it 'does not inherit approval from the old category during a category-only edit' do
    revision.update!(status: :approved, provider_template_id: 'meta-approved')
    category_edit = WhatsappTemplateRevision.create!(
      whatsapp_template: template, account: account, channel: channel, revision_number: 2,
      language: 'en_US', category: 'MARKETING', body: 'Order ready', submission_key: 'submission-category-edit',
      content_digest: 'category-edit-digest', status: :unknown, submitted_at: Time.current, submitted_by: admin
    )
    status_request = stub_request(:get, "#{endpoint}?name=order_update").to_return(
      status: 200,
      body: { data: [{ id: 'meta-approved', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'APPROVED',
                       components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(revision: category_edit).perform(reconcile: true)

    expect(status_request).to have_been_requested.once
    expect(category_edit.reload).to have_attributes(status: 'unknown', provider_template_id: nil)
    expect(revision.reload).not_to be_sendable
  end

  it 'does not bind a different provider ID to a revision that already has a known provider identity' do
    revision.update!(status: :unknown, provider_template_id: 'meta-expected')
    status_request = stub_request(:get, "#{endpoint}?name=order_update").to_return(
      status: 200,
      body: { data: [{ id: 'meta-other', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'APPROVED',
                       components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(revision: revision).perform(reconcile: true)

    expect(status_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'unknown', provider_template_id: 'meta-expected')
  end

  it 'records a definitive provider rejection instead of losing a 4xx response as unknown' do
    provider_request = stub_request(:post, endpoint).to_return(
      status: 400,
      body: { error: { message: 'Invalid template category', code: 100 } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(revision: revision).perform

    expect(provider_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'rejected', rejection_reason: 'Invalid template category (code 100)')
  end

  it 'timestamps every unresolved reconciliation attempt even when the state remains unknown' do
    previous_sync = 2.hours.ago.change(usec: 0)
    revision.update!(status: :unknown, status_synced_at: previous_sync)
    status_request = stub_request(:get, "#{endpoint}?name=order_update").to_return(status: 503)
    current_sync = Time.zone.parse('2026-09-12 20:45:00')

    travel_to(current_sync) { described_class.new(revision: revision).perform(reconcile: true) }

    expect(status_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'unknown', status_synced_at: current_sync)
  end

  it 'records rejection details and later paused or disabled provider states' do
    status_request = stub_request(:get, "#{endpoint}?name=order_update")
                     .to_return(
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'REJECTED',
                                                       rejected_reason: 'INVALID_FORMAT',
                                                       components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' } },
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'PAUSED',
                                                       components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' } },
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', language: 'en_US', category: 'UTILITY', status: 'DISABLED',
                                                       components: [{ type: 'BODY', text: 'Order ready' }] }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' } }
                     )
    revision.update!(status: :unknown)

    service = described_class.new(revision: revision)
    described_class.new(revision: revision.reload).perform(reconcile: true)
    expect(revision.reload).to have_attributes(status: 'rejected', rejection_reason: 'INVALID_FORMAT')
    service.perform(reconcile: true)
    expect(revision.reload.status).to eq('paused')
    service.perform(reconcile: true)
    expect(revision.reload.status).to eq('disabled')
    expect(status_request).to have_been_requested.times(3)
  end
end
