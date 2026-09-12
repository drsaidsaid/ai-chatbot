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
  let(:endpoint) { 'https://graph.facebook.com/v14.0/waba-r26/message_templates' }

  it 'claims a pending revision once so duplicate jobs cannot create duplicate Meta templates' do
    create_request = stub_request(:post, endpoint).to_return(
      status: 200, body: { id: 'meta-1' }.to_json, headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(revision: revision).perform
    described_class.new(revision: revision.reload).perform

    expect(create_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'submitted', provider_template_id: 'meta-1')
  end

  it 'reconciles an uncertain timeout without repeating Meta creation' do
    create_request = stub_request(:post, endpoint).to_timeout
    status_request = stub_request(:get, "#{endpoint}?name=order_update")
                     .to_return(status: 200, body: { data: [{ id: 'meta-2', name: 'order_update', status: 'APPROVED' }] }.to_json,
                                headers: { 'Content-Type' => 'application/json' })

    described_class.new(revision: revision).perform
    described_class.new(revision: revision.reload).perform
    described_class.new(revision: revision.reload).perform(reconcile: true)

    expect(create_request).to have_been_requested.once
    expect(status_request).to have_been_requested.once
    expect(revision.reload).to have_attributes(status: 'approved', provider_template_id: 'meta-2')
  end

  it 'records rejection details and later paused or disabled provider states' do
    status_request = stub_request(:get, "#{endpoint}?name=order_update")
                     .to_return(
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', status: 'REJECTED',
                                                       rejected_reason: 'INVALID_FORMAT' }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' } },
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', status: 'PAUSED' }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' } },
                       { status: 200, body: { data: [{ id: 'meta-3', name: 'order_update', status: 'DISABLED' }] }.to_json,
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
