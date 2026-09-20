# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Orchestration::IntentProcessor do
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:account) { channel.account }
  let(:contact) { create(:contact, account: account, phone_number: '+255700444321') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700444321') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active, status: :open, assignee: nil)
  end
  let(:provider_client) { instance_double(AiLeadEmployee::AiProvider::MeteredClient) }

  before do
    create(:ai_subscription, account: account, period_started_at: Time.current.beginning_of_day,
                             renews_at: 1.month.from_now.beginning_of_day, renewal_anchor_day: Time.current.day)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
  end

  it 'persists a unique exact Offer selection and carries it through the outgoing authority check' do
    offer = create_offer(name: 'Online Profits University', configuration: enabled_offer_configuration)
    answer = 'Online Profits University helps people build an online business through a 12-month mentoring programme.'
    create(:knowledge_document, account: account, title: offer.name, body: answer,
                                general_question_access: false, offer_ids: [offer.id])
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'exact-offer-context', model: connection.model, content: answer, finish_reason: 'stop',
        configuration_version: connection.configuration_version
      )
    )
    incoming = create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'What does Online Profits University help people do, and how long is the mentoring programme?',
      source_id: 'wamid.exact-offer-context',
      provider_created_at: Time.current
    )
    intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                              triggering_message: incoming, observed_control_version: conversation.control_version)

    conversation.reload
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(conversation.reload.offer).to eq(offer)
    expect(intent.outbound_message.content).to eq(answer)
    offer_context = intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'offer_context')
    expect(offer_context).to include('offer_id' => offer.id, 'selection_version' => conversation.offer_selection_version)
    expect(AiLeadEmployee::OfferAnswerContext.new(conversation: conversation, context: offer_context).failure_code).to be_nil
    expect_delivery_is_authorized(intent.outbound_message, connection)
    expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification_context')).to include(
      'offer_id' => offer.id, 'configuration_version' => offer.configuration_version
    )
  end

  %w[configuration disable selection].each do |change|
    it "rechecks the persisted exact Offer after a provider-time #{change} before completing a grounded answer" do
      offer = create_offer(name: 'Online Profits University', configuration: enabled_offer_configuration)
      answer = 'Online Profits University helps people build an online business through a 12-month mentoring programme.'
      create(:knowledge_document, account: account, title: offer.name, body: answer,
                                  general_question_access: false, offer_ids: [offer.id])
      connection = create(:ai_provider_connection, account: account)
      allow(provider_client).to receive(:complete) do
        apply_provider_time_offer_change!(change, offer)
        AiLeadEmployee::AiProvider::Response.new(
          id: "exact-offer-#{change}", model: connection.model, content: answer, finish_reason: 'stop',
          configuration_version: connection.configuration_version
        )
      end
      incoming = create(
        :message,
        account: account,
        inbox: channel.inbox,
        conversation: conversation,
        sender: contact,
        message_type: :incoming,
        content: 'What does Online Profits University help people do, and how long is the mentoring programme?',
        source_id: "wamid.exact-offer-#{change}",
        provider_created_at: Time.current
      )
      intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                                triggering_message: incoming, observed_control_version: conversation.control_version)

      conversation.reload
      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
      expect(intent.review_request).to have_attributes(reason: 'source_unverified', status: 'open')
      expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'outbound_intent_status')).to eq('review_acknowledgment')
    end
  end

  it 'preserves an explicitly selected Conversation Offer over a differently named message fallback' do
    selected_offer = create_offer(name: 'Selected coaching')
    mentioned_offer = create_offer(name: 'Online Profits University')
    conversation.update!(offer: selected_offer)
    answer = 'Selected coaching is the current discussion context.'
    create(:knowledge_document, account: account, title: selected_offer.name, body: answer,
                                general_question_access: false, offer_ids: [selected_offer.id])
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'selected-offer-context', model: connection.model, content: answer, finish_reason: 'stop',
        configuration_version: connection.configuration_version
      )
    )
    incoming = create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'What does Online Profits University help people do?',
      source_id: 'wamid.selected-offer-context',
      provider_created_at: Time.current
    )
    intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                              triggering_message: incoming, observed_control_version: conversation.control_version)

    conversation.reload
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to be_completed
    expect(conversation.reload.offer).to eq(selected_offer)
    expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'offer_context', 'offer_id')).to eq(selected_offer.id)
    expect(mentioned_offer).not_to eq(conversation.offer)
  end

  def create_offer(name:, configuration: disabled_offer_configuration)
    AiLeadEmployee::Offer.create!(
      account: account,
      name: name,
      currency: 'USD',
      enabled: true,
      configuration: configuration
    )
  end

  def expect_delivery_is_authorized(message, connection)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    delivery = message.whatsapp_outbound_delivery
    result = Whatsapp::OutboundEligibility.new(
      delivery: delivery,
      channel: channel,
      recipient: contact_inbox.source_id,
      authority_records: { provider_connection: connection }
    ).failure_code

    expect(result).to be_nil
  end

  def disabled_offer_configuration
    { 'qualification_mode' => 'disabled', 'next_step' => { 'kind' => 'answer_only' } }
  end

  def enabled_offer_configuration
    {
      'qualification_mode' => 'enabled',
      'next_step' => { 'kind' => 'answer_only' },
      'questions' => enabled_questions,
      'budget_ranges' => [],
      'rules' => [],
      'score_weights' => {},
      'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
    }
  end

  def enabled_questions
    %w[business_type main_goal audience offer_stage budget timeline decision_maker].each_with_index.map do |key, position|
      {
        'key' => key, 'meaning' => key.humanize, 'answer_type' => 'text',
        'prompt' => "What is your #{key.humanize.downcase}?", 'position' => position,
        'enabled' => true, 'required' => true, 'purpose' => 'fit'
      }
    end
  end

  def apply_provider_time_offer_change!(change, offer)
    case change
    when 'configuration'
      offer.update!(configuration_version: offer.configuration_version + 1)
    when 'disable'
      offer.update!(enabled: false)
    when 'selection'
      conversation.update!(offer: create_offer(name: 'Different Offer', configuration: enabled_offer_configuration))
    end
  end
end
