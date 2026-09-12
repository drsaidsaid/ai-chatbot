# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhatsappTemplateRevision do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider_config: {}, sync_templates: false,
                              validate_provider_config: false).tap do |record|
      record.update_columns(provider: 'whatsapp_cloud', provider_config: { 'business_account_id' => 'waba-r26' }) # rubocop:disable Rails/SkipsModelValidations
    end
  end
  let(:template) { WhatsappTemplate.create!(account: account, channel: channel, created_by: admin, name: 'order_update') }

  def build_revision(overrides = {})
    attributes = {
      whatsapp_template: template,
      account: account,
      channel: channel,
      revision_number: 1,
      language: 'en_US',
      category: 'UTILITY',
      body: 'Hello {{1}}',
      variables: [{ 'position' => 1, 'example' => 'Asha' }],
      submission_key: SecureRandom.uuid,
      content_digest: 'digest'
    }.merge(overrides)
    described_class.new(attributes)
  end

  def create_revision(overrides = {})
    build_revision(overrides).tap(&:save!)
  end

  it 'validates the recipient preview variables and known Meta cost evidence', :aggregate_failures do
    missing_variable = build_revision(body: 'Hello {{1}} and {{2}}', variables: [{ 'position' => 1 }])
    incomplete_cost = build_revision(revision_number: 2, meta_charge_estimate: { 'amount' => '0.00', 'currency' => 'USD' })

    expect(missing_variable).not_to be_valid
    expect(missing_variable.errors[:variables]).to be_present
    expect(incomplete_cost).not_to be_valid
    expect(incomplete_cost.errors[:meta_charge_estimate]).to be_present
  end

  it 'rejects template components that Meta cannot submit', :aggregate_failures do
    missing_example = build_revision(variables: [{ 'position' => 1, 'example' => '' }])
    invalid_media = build_revision(revision_number: 2, media: { 'format' => 'AUDIO', 'example' => {} })
    invalid_url_button = build_revision(
      revision_number: 3,
      buttons: [{ 'type' => 'URL', 'text' => 'View order', 'url' => '' }]
    )
    invalid_phone_button = build_revision(
      revision_number: 4,
      buttons: [{ 'type' => 'PHONE_NUMBER', 'text' => 'Call us', 'phone_number' => '' }]
    )

    expect(missing_example).not_to be_valid
    expect(missing_example.errors[:variables]).to be_present
    expect(invalid_media).not_to be_valid
    expect(invalid_media.errors[:media]).to be_present
    expect(invalid_url_button).not_to be_valid
    expect(invalid_url_button.errors[:buttons]).to be_present
    expect(invalid_phone_button).not_to be_valid
    expect(invalid_phone_button.errors[:buttons]).to be_present
  end

  it 'keeps submitted content immutable while allowing provider status reconciliation' do
    revision = create_revision(status: :submitted, submitted_at: Time.current, provider_template_id: 'meta-1')

    expect(revision.update(body: 'Mutated after submission')).to be(false)
    expect(revision.reload.body).to eq('Hello {{1}}')
    expect(revision.update(status: :approved, status_synced_at: Time.current)).to be(true)
    expect(revision).to be_sendable
  end

  it 'keeps the Meta template language fixed when an approved provider template is edited' do
    create_revision(status: :approved, submitted_at: Time.current, provider_template_id: 'meta-1')
    translated_edit = build_revision(revision_number: 2, language: 'sw')

    expect(translated_edit).not_to be_valid
    expect(translated_edit.errors[:language]).to include('cannot change when editing an existing Meta template')
  end

  it 'never treats an older approval as sendable after a newer revision exists' do
    approved = create_revision(status: :approved, submitted_at: Time.current, provider_template_id: 'meta-1')
    expect(approved).to be_sendable

    current_draft = create_revision(revision_number: 2)

    expect(approved.reload).not_to be_sendable
    expect(current_draft).not_to be_sendable
  end

  it 'shows missing Meta pricing as unknown rather than zero' do
    revision = create_revision

    expect(revision.meta_charge_estimate).to eq({})
    expect(revision.preview).to include('body' => 'Hello {{1}}')
  end
end
