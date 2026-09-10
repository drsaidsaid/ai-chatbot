# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OrchestrationIntentJob do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:account) { channel.account }
  let(:contact) { create(:contact, account: account, phone_number: '+255700111231') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700111231') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active, control_version: 4, assignee: nil, status: :open)
  end
  let(:triggering_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'This is a scam. I want a human to handle my complaint.')
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation,
                                     triggering_message: triggering_message, observed_control_version: 4)
  end

  before do
    intent
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(SendReplyJob).to receive(:perform_later)
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_call_original
  end

  it 'records one complaint Review and fixed acknowledgment before any sales qualification under duplicate jobs', :aggregate_failures do
    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question')
    expect(intent.review_request).to have_attributes(reason: 'angry_question', status: 'open', lead_message: triggering_message)
    expect(contact.reload.lead_qualification).to be_nil
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(conversation.reload).to have_attributes(control_state: 'ai_active', assignee_id: nil)
    expect(intent.outbound_message&.content).to eq(
      'I am sorry you have had this experience. I have recorded your complaint for the team to review.'
    )
    expect(intent.decision).to include(
      'acknowledgment' => include('status' => 'recorded', 'review_request_id' => intent.review_request_id)
    )
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
    outbox = OutboxEvent.find_by(idempotency_key: "ai-outbound/#{intent.id}")
    expect(outbox).to have_attributes(aggregate: intent.outbound_message, state: 'pending')
    expect(AiLeadEmployee::OutboxDispatchJob).to have_received(:perform_later).with(outbox&.id).once
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'keeps an unanswered business question blocked while acknowledging its persisted Review without sales questions', :aggregate_failures do
    triggering_message.update!(content: 'Do you offer AI employees?')

    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open')
    expect(intent.outbound_message&.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(intent.outbound_message&.additional_attributes&.dig('ai_lead_employee', 'review_request_id')).to eq(intent.review_request_id)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'retains the actual HTTP 402 failure and enqueues one fixed acknowledgment of its persisted Review', :aggregate_failures do
    create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
    triggering_message.update!(content: 'Do you offer AI employees?')
    create(:knowledge_item, account: account, question: triggering_message.content, answer: 'Yes, we build AI employees.')
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .to_return(status: 402, body: { error: { message: 'Synthetic provider failure detail.' } }.to_json)

    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    expect(request).to have_been_requested.once
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure', failure_class: 'insufficient_credits')
    expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
    expect(intent.decision).to include('status' => 'provider_failed', 'failure_class' => 'insufficient_credits')
    expect(intent.outbound_message&.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(intent.decision).to include('acknowledgment' => include('status' => 'recorded', 'review_request_id' => intent.review_request_id))
    expect(conversation.messages.outgoing.count).to eq(1)
    outbox = OutboxEvent.find_by(idempotency_key: "ai-outbound/#{intent.id}")
    expect(outbox).to have_attributes(aggregate: intent.outbound_message, state: 'pending')
    expect(AiLeadEmployee::OutboxDispatchJob).to have_received(:perform_later).with(outbox&.id).once
  end

  it 'shows the current Review disposition instead of an earlier grounded answer in the conversation decision', :aggregate_failures do
    source = create(:knowledge_item, account: account)
    conversation.update!(additional_attributes: {
                           'ai_employee_last_decision' => {
                             'status' => 'grounded_answer', 'sources' => [{ 'type' => 'knowledge_item', 'id' => source.id, 'status' => 'verified' }]
                           }
                         })

    described_class.perform_now(intent.id)

    expect(conversation.reload.additional_attributes['ai_employee_last_decision']).to include(
      'status' => 'review_required',
      'refusal_reason' => 'angry_question',
      'review_request_id' => intent.reload.review_request_id,
      'sources' => [],
      'acknowledgment' => include('status' => 'recorded', 'outbound_message_id' => intent.outbound_message_id)
    )
  end

  it 'answers a Swahili greeting without creating a false knowledge Review', :aggregate_failures do
    triggering_message.update!(content: 'Habari')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', blocked_reason: nil, review_request: nil)
    expect(intent.decision).to include('status' => 'conversation_reply')
    expect(intent.outbound_message&.content).to eq(
      "Habari. Ninaweza kukusanya taarifa chache ili timu yetu ikusaidie.\n\nUnaendesha biashara ya aina gani?"
    )
    expect(intent.source_references).to eq([])
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'acknowledges persisted business details and asks the actual next question without claiming a Review', :aggregate_failures do
    triggering_message.update!(content: 'I run an agency.')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(contact.reload.lead_qualification.evidence_snapshot.dig('business_type', 'value')).to include('agency')
    evidence = QualificationEvidence.current.find_by!(contact: contact, signal: :business_type)
    expect(evidence.message).to eq(triggering_message)
    expect(intent.outbound_message&.content).to eq("Thanks for those details.\n\nWhat problem are you trying to solve right now?")
    expect(intent.outbound_message&.additional_attributes&.dig('ai_lead_employee', 'qualification', 'next_question')).to eq(
      'What problem are you trying to solve right now?'
    )
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'continues after a simple Swahili acknowledgment without promising a nonexistent Review', :aggregate_failures do
    triggering_message.update!(content: 'Sawa')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message&.content).to eq("Asante kwa ujumbe wako.\n\nUnaendesha biashara ya aina gani?")
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'uses the configured staff-request policy for a genuine Swahili request without a knowledge Review', :aggregate_failures do
    explanation = 'I need to qualify the request before handing this to a Human Operator.'
    account.update!(settings: {
                      'ai_lead_employee' => { 'unqualified_human_request_explanation' => explanation }
                    })
    triggering_message.update!(content: 'Nataka kuzungumza na mtu wa timu yenu.')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.decision).to include('status' => 'qualification_question')
    expect(intent.outbound_message&.content).to eq(
      "I need to qualify the request before handing this to a Human Operator.\n\nUnaendesha biashara ya aina gani?"
    )
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(0)
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'clarifies an unclear message instead of asking a pending sales question', :aggregate_failures do
    triggering_message.update!(content: 'That thing from before.')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Could you tell me what you need help with?')
    expect(QualificationEvidence.where(message: triggering_message)).to be_empty
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'routes a first-person how-to-contact question through the staff policy', :aggregate_failures do
    triggering_message.update!(content: 'How can I speak to a human?')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.decision['status']).to eq('qualification_question')
    expect(intent.outbound_message.content).to start_with(
      AiLeadEmployee::HighlyQualifiedHandoffService.unqualified_human_request_explanation(account)
    )
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'acknowledges ordinary sales help instead of invoking staff-request policy', :aggregate_failures do
    triggering_message.update!(content: 'I need help increasing sales.')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.decision).to include('status' => 'conversation_reply')
    expect(intent.outbound_message&.content).to start_with('Thanks for those details.')
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  [
    ['This is unacceptable.', 'angry_question', 'I am sorry you have had this experience. I have recorded your complaint for the team to review.'],
    ['Nina malalamiko. Nataka kuzungumza na mtu.', 'angry_question', 'Pole kwa hali hii. Nimeweka malalamiko yako kwa timu ili iyapitie.'],
    ['Please refund my payment.', 'sensitive_question', 'I have recorded your refund request for the team to review.'],
    ['Siwezi kuingia kwenye kozi.', 'sensitive_question', 'Nimeweka ombi lako la msaada kwa timu ili ilipitie.']
  ].each do |content, reason, acknowledgment|
    it "routes #{content} before qualification and sends only its fixed acknowledgment", :aggregate_failures do
      triggering_message.update!(content: content)

      described_class.perform_now(intent.id)

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: reason)
      expect(intent.review_request.reason).to eq(reason)
      expect(intent.outbound_message.content).to eq(acknowledgment)
      expect(contact.reload.lead_qualification).to be_nil
      expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
      expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
    end
  end

  [
    ['Tell me about your course.', :faq, 'Our course covers the basics of business automation.'],
    ['Hello, what is your refund policy?', :refund, 'Refund requests require a review against the published policy.'],
    ['What support do you offer?', :faq, 'We offer email support.']
  ].each do |question, kind, answer|
    it "preserves the grounded path for the approved informational question #{question}", :aggregate_failures do
      triggering_message.update!(content: question)
      create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
      source = create(:knowledge_item, account: account, question: question, answer: answer, source_kind: kind)
      request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(
        status: 200, body: { choices: [{ message: { role: 'assistant', content: answer }, finish_reason: 'stop' }] }.to_json
      )

      described_class.perform_now(intent.id)

      expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(intent.decision['status']).to eq('grounded_answer')
      expect(intent.source_references).to contain_exactly(include('id' => source.id, 'status' => 'verified'))
      expect(intent.outbound_message.content).to start_with(answer)
      expect(request).to have_been_requested.once
    end
  end

  it 'suppresses the acknowledgment when human takeover revokes authority before an actual provider failure returns', :aggregate_failures do
    triggering_message.update!(content: 'Do you offer AI employees?')
    create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
    create(:knowledge_item, account: account, question: triggering_message.content)
    operator = create(:user, :administrator, account: account)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do
      Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: operator)
      { status: 402, body: '{"error":{"message":"Synthetic late failure"}}' }
    end

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'assigned_to_human_operator', review_request: nil,
                                             outbound_message: nil, failure_class: nil)
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(0)
    expect(request).to have_been_requested.once
  end

  it 'acknowledges a source withdrawn during generation without sending the now-unverified provider answer', :aggregate_failures do
    triggering_message.update!(content: 'Do you offer AI employees?')
    create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
    source = create(:knowledge_item, account: account, question: triggering_message.content)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do
      source.update!(status: :inactive, deactivated_at: Time.current)
      { status: 200, body: { choices: [{ message: { role: 'assistant', content: 'Synthetic withdrawn answer.' }, finish_reason: 'stop' }] }.to_json }
    end

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(intent.review_request.reason).to eq('source_unverified')
    expect(intent.outbound_message.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(request).to have_been_requested.once
  end

  it 'uses actual Swahili question context to record an unknown answer and ask the next unanswered question', :aggregate_failures do
    triggering_message.update!(content: 'Nina biashara ya coaching.')
    described_class.perform_now(intent.id)
    expect(intent.reload.outbound_message.content).to eq("Asante kwa maelezo.\n\nUnajaribu kutatua changamoto gani kwa sasa?")
    answer = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                              message_type: :incoming, content: 'Sijui.')
    answer_intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: answer, enqueue: false).perform

    described_class.perform_now(answer_intent.id)

    snapshot = contact.reload.lead_qualification.evidence_snapshot
    expect(snapshot.fetch('business_type')).to include('message_id' => triggering_message.id, 'polarity' => 'positive')
    expect(snapshot.fetch('problem')).to include('message_id' => answer.id, 'value' => 'unknown', 'polarity' => 'unknown')
    expect(contact.lead_qualification.missing_signals).to include('problem')
    expect(answer_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(answer_intent.outbound_message.content).to eq("Asante kwa maelezo.\n\nUnapata leads au maulizo mangapi kwa mwezi?")
    expect(answer_intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification', 'next_question')).to eq(
      'How many leads or inquiries do you handle each month?'
    )
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'does not turn an informational imperative after a business question into evidence, including later history replay', :aggregate_failures do
    triggering_message.update!(content: 'Habari')
    described_class.perform_now(intent.id)
    inquiry = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                               message_type: :incoming, content: 'Tell me about your course.')
    create(:knowledge_item, account: account, question: inquiry.content, answer: 'Our course covers business automation.')
    create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(
      status: 200,
      body: { choices: [{ message: { role: 'assistant', content: 'Our course covers business automation.' }, finish_reason: 'stop' }] }.to_json
    )
    inquiry_intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: inquiry, enqueue: false).perform

    described_class.perform_now(inquiry_intent.id)

    expect(inquiry_intent.reload.decision['status']).to eq('grounded_answer')
    expect(contact.reload.lead_qualification.evidence_snapshot).not_to have_key('business_type')
    expect(QualificationEvidence.where(message: inquiry, signal: :business_type)).to be_empty
    later_message = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                                     message_type: :incoming, content: 'Thanks.')
    later_intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: later_message, enqueue: false).perform
    described_class.perform_now(later_intent.id)

    expect(contact.reload.lead_qualification.evidence_snapshot).not_to have_key('business_type')
    expect(QualificationEvidence.current.where(contact: contact, signal: :business_type)).to be_empty
    expect(provider_request).to have_been_requested.once
  end

  it 'retains a budget correction and its source history while asking only the next unanswered question', :aggregate_failures do
    create(:qualification_question, account: account, signal: :budget, prompt: 'What budget range have you set aside for this?', position: 1)
    create(:qualification_question, account: account, signal: :business_type, prompt: 'What type of business do you run?', position: 2)
    triggering_message.update!(content: 'My budget is TZS 500000.')
    described_class.perform_now(intent.id)
    expect(contact.reload.lead_qualification.evidence_snapshot.fetch('budget')).to include(
      'message_id' => triggering_message.id, 'polarity' => 'positive', 'currency' => 'TZS', 'amount_minor' => 50_000_000
    )
    expect(intent.reload.outbound_message.content).to eq("Thanks for those details.\n\nWhat type of business do you run?")
    expect(contact.lead_qualification).not_to be_highly_qualified
    correction = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                                  message_type: :incoming, content: 'Correction, I have no budget.')
    correction_intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: correction, enqueue: false).perform

    described_class.perform_now(correction_intent.id)

    qualification = contact.reload.lead_qualification
    expect(qualification.evidence_snapshot.fetch('budget')).to include('message_id' => correction.id, 'polarity' => 'negative')
    expect(qualification.evidence_snapshot).not_to have_key('business_type')
    expect(qualification.missing_signals).to include('budget')
    expect(qualification).not_to be_highly_qualified
    records = QualificationEvidence.where(contact: contact, signal: :budget).order(:id)
    expect(records.count).to eq(2)
    expect(records.first.superseded_by).to eq(records.last)
    expect(correction_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(correction_intent.outbound_message.content).to eq("Thanks for those details.\n\nWhat type of business do you run?")
    expect(correction_intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification', 'next_question')).to eq(
      'What type of business do you run?'
    )
    expect(LeadHandoff.where(conversation: conversation).count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  context 'with controlled provider failures for a Swahili question' do
    before do
      create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
      triggering_message.update!(content: 'Online Profits ni nini?')
      create(:knowledge_item, account: account, question: triggering_message.content, answer: 'Online Profits ni brand ya elimu na coaching.')
    end

    [
      ['timeout', 'timeout', :timeout],
      ['malformed JSON', 'invalid_response', '{broken-json'],
      ['safety refusal', 'safety_refusal', { choices: [{ message: { role: 'assistant', refusal: 'Synthetic refusal detail.' },
                                                         finish_reason: 'stop' }] }.to_json],
      ['truncation', 'invalid_response', { choices: [{ message: { role: 'assistant', content: 'Synthetic partial provider answer.' },
                                                       finish_reason: 'length' }] }.to_json]
    ].each do |name, failure_class, body|
      it "acknowledges #{name} once in Swahili while retaining the original failure", :aggregate_failures do
        request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
        body == :timeout ? request.to_timeout : request.to_return(status: 200, body: body)

        described_class.perform_now(intent.id)
        described_class.perform_now(intent.id)

        expect(request).to have_been_requested.once
        expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure', failure_class: failure_class)
        expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
        expect(intent.decision).to include('status' => 'provider_failed', 'failure_class' => failure_class)
        expect(intent.outbound_message&.content).to eq('Bado sina jibu lililothibitishwa. Nimeweka swali lako kwa timu ili ilipitie.')
        expect(conversation.messages.outgoing.count).to eq(1)
        expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
        expect(AiLeadEmployee::OutboxDispatchJob).to have_received(:perform_later).once
      end
    end
  end
end
