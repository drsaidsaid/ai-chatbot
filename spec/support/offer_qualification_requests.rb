# frozen_string_literal: true

module OfferQualificationRequests
  def r09_question(key, answer_type:, prompt:, **attributes)
    { 'key' => key, 'meaning' => key.humanize, 'answer_type' => answer_type,
      'prompt' => prompt, 'position' => 0, 'enabled' => true, 'required' => true, 'purpose' => 'fit' }.merge(attributes.stringify_keys)
  end

  def r09_configuration(name: 'Message support', currency: 'TZS', minimum: '500000.00', questions: nil, **attributes)
    legacy_contract = attributes.delete(:legacy_contract) { true }
    questions ||= [r09_question('budget', answer_type: 'money', prompt: 'What can you spend on this Offer?'),
                   r09_question('problem', answer_type: 'text', prompt: 'What problem should this Offer solve?', position: 1)]
    rules = configured_rules(attributes, legacy_contract, minimum, currency)
    weights = configured_weights(attributes, legacy_contract)
    { 'name' => name, 'currency' => currency, 'enabled' => true, 'qualification_mode' => 'enabled',
      'next_step' => { 'kind' => legacy_contract ? 'sales_call' : 'answer_only' }, 'questions' => questions,
      'budget_ranges' => [{ 'label' => 'Supported budget', 'minimum' => minimum, 'maximum' => nil, 'enabled' => true, 'position' => 0 }],
      'rules' => rules, 'score_weights' => weights,
      'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 } }.merge(attributes.stringify_keys)
  end

  def configured_rules(attributes, legacy_contract, minimum, currency)
    return Array(attributes.delete(:rules)) if attributes.key?(:rules)

    legacy_contract ? legacy_offer_rules(minimum, currency) : []
  end

  def configured_weights(attributes, legacy_contract)
    return attributes.delete(:score_weights) || {} if attributes.key?(:score_weights)

    legacy_contract ? AiLeadEmployee::QualificationService::SIGNAL_WEIGHTS : {}
  end

  def legacy_offer_rules(minimum, currency)
    %w[problem urgency decision_authority].map do |field|
      { kind: 'requirement', dimension: 'fit', field: field, operator: 'positive', value: nil, priority: 0, enabled: true }
    end + [
      { kind: 'requirement', dimension: 'fit', field: 'budget', operator: 'gte',
        value: { amount: minimum, currency: currency }, priority: 0, enabled: true },
      { kind: 'hard_rule', field: 'budget', operator: 'lt', value: { amount: minimum, currency: currency },
        forced_outcome: 'unqualified', priority: 0, enabled: true }
    ]
  end

  def r09_create_offer(configuration = r09_configuration)
    post r09_offers_url, headers: r09_headers, params: { offer: configuration }, as: :json
    expect(response).to have_http_status(:created)
    response.parsed_body
  end

  def r09_update_offer(offer, **changes)
    patch "#{r09_offers_url}/#{offer.fetch('id')}", headers: r09_headers,
                                                    params: { offer: offer.merge(changes.stringify_keys) }, as: :json
  end

  def r09_conversation(offer: nil, contact: r09_lead)
    conversation = create(:conversation, account: account, inbox: r09_channel.inbox, contact: contact,
                                         control_state: :ai_active, control_version: 1, assignee: nil, status: :open)
    if offer
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/qualification_offer",
            headers: r09_headers, params: { offer_id: offer.fetch('id') }, as: :json
      expect(response).to have_http_status(:success)
    end
    conversation.reload
  end

  def r09_receive(conversation, content)
    message = create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                               sender: conversation.contact, message_type: :incoming, content: content)
    intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                              triggering_message: message, observed_control_version: conversation.reload.control_version)
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    [message, intent.reload]
  end

  def r09_qualification(offer)
    LeadQualification.find_by!(account: account, contact: r09_lead, offer_id: offer.fetch('id'))
  end

  def r09_offers_url
    "/api/v1/accounts/#{account.id}/qualification_offers"
  end

  def r09_prepare_request_context
    create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later)
    allow(SendReplyJob).to receive(:perform_later)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to receive(:for)
  end
end

RSpec.shared_context 'with Offer qualification requests' do
  include OfferQualificationRequests

  let(:account) { create(:account) }
  let(:r09_admin) { create(:user, account: account, role: :administrator) }
  let(:r09_headers) { r09_admin.create_new_auth_token }
  let(:r09_lead) { create(:contact, account: account, name: 'Asha', phone_number: '+255700111231') }
  let(:r09_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end

  before do
    r09_prepare_request_context
  end
end
