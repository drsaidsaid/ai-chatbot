# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Orchestration::IntentProcessor do
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:account) { channel.account }
  let(:contact) { create(:contact, account: account, phone_number: '+255700444321') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700444321') }
  let(:offer) { create_offer }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active, control_version: 2, assignee: nil, status: :open, offer: offer)
  end

  before do
    create(:ai_subscription, account: account, period_started_at: Time.current.beginning_of_day,
                             renews_at: 1.month.from_now.beginning_of_day, renewal_anchor_day: Time.current.day)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for)
  end

  %w[no_published_price price_not_current].each do |pricing_reason|
    it "routes #{pricing_reason} through an approved-data review without an AI or delivery call" do
      expire_published_price! if pricing_reason == 'price_not_current'
      incoming = create(
        :message,
        account: account,
        inbox: channel.inbox,
        conversation: conversation,
        sender: contact,
        message_type: :incoming,
        content: "What is the price of #{offer.name}?",
        source_id: "wamid.pricing.#{pricing_reason}",
        provider_created_at: Time.current
      )
      intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                                triggering_message: incoming, observed_control_version: conversation.control_version)

      conversation.reload
      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: pricing_reason.to_s)
      expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open', question: incoming.content)
      expect(intent.outbound_message.content).to eq(
        'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
      )
      expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'outbound_intent_status')).to eq('review_acknowledgment')
      expect(OutboxEvent.where(aggregate: intent.outbound_message)).to exist
      expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
    end
  end

  def create_offer
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Growth coaching',
      currency: 'USD',
      enabled: true,
      configuration: {
        'qualification_mode' => 'disabled',
        'next_step' => { 'kind' => 'answer_only' },
        'questions' => [],
        'budget_ranges' => [],
        'rules' => [],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
  end

  def expire_published_price!
    editor = create(:user, account: account, role: :administrator)
    draft = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: {
        amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC',
        effective_until: 1.hour.ago.iso8601
      }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: draft.draft_version, editor: editor)
    conversation.reload
  end
end
