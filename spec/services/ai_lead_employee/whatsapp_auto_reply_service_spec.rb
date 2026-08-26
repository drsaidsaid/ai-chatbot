# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::WhatsappAutoReplyService do
  let(:account) do
    create(
      :account,
      settings: {
        'ai_lead_employee' => {
          'unqualified_human_request_explanation' => 'I need to qualify the request before handing this to a Human Operator.'
        }
      }
    )
  end
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => 'test-key',
        'phone_number_id' => '111222333',
        'business_account_id' => '444555666',
        'source' => 'embedded_signup'
      }
    )
  end
  let(:contact) { create(:contact, account: account, phone_number: '+255712345678') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      control_state: :ai_active,
      control_version: 0
    )
  end
  let(:incoming_message) do
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Please give me a human. My budget is $50.'
    )
  end

  before do
    create(:knowledge_item, account: account, question: 'human', answer: 'I can help with approved information.')
    create(:qualification_question, account: account, signal: :budget, prompt: 'What budget range have you set aside?', position: 1)
    create(:qualification_question, account: account, signal: :problem, prompt: 'What problem should we solve?', position: 2)
    create(:qualification_budget_range, account: account, min_cents: 100_000, max_cents: nil)
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.AUTO_REPLY' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'explains that an unqualified human request must continue qualification without handoff' do
    described_class.new(
      conversation: conversation,
      incoming_message: incoming_message,
      provider_message_payload: { type: 'text' }
    ).perform

    expect(Message.outgoing.last.content).to eq(
      "I need to qualify the request before handing this to a Human Operator.\n\nWhat problem should we solve?"
    )
    expect(conversation.reload).to be_ai_active
    expect(conversation.assignee_id).to be_nil
    expect(LeadHandoff.count).to eq(0)
  end
end
