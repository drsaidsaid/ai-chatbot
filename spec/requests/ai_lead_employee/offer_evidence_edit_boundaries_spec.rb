# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer evidence edit boundaries', type: :request do
  include_context 'with Offer qualification requests'

  def edit_evidence(offer, conversation, **attributes)
    post(
      "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
      headers: r09_headers,
      params: { offer_id: offer.fetch('id'), conversation_id: conversation.display_id, signal: 'budget', value: 'TZS 250000' }.merge(attributes),
      as: :json
    )
  end

  it 'rejects a different Offer from the current Conversation selection without writing any evidence' do
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Second Offer'))
    conversation = r09_conversation(offer: first)

    expect { edit_evidence(second, conversation) }.not_to(change(QualificationEvidence, :count))
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects a Conversation belonging to a different Lead' do
    offer = r09_create_offer(r09_configuration)
    r09_conversation(offer: offer)
    other = r09_conversation(offer: offer, contact: create(:contact, account: account))

    expect { edit_evidence(offer, other) }.not_to(change(QualificationEvidence, :count))
    expect(response).to have_http_status(:not_found)
  end

  it 'does not allow a member to edit an unassigned Conversation of an otherwise accessible Lead' do
    offer = r09_create_offer(r09_configuration)
    member = create(:user, account: account, role: :agent)
    assigned = r09_conversation(offer: offer)
    assigned.update!(assignee: member)
    hidden = r09_conversation(offer: offer)

    expect do
      post(
        "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
        headers: member.create_new_auth_token,
        params: { offer_id: offer.fetch('id'), conversation_id: hidden.display_id, signal: 'budget', value: 'TZS 250000' },
        as: :json
      )
    end.not_to(change(QualificationEvidence, :count))
    expect(response).to have_http_status(:not_found)
  end

  it 'accepts an explicit false custom human answer and preserves its source and Offer context' do
    question = r09_question('uses_crm', answer_type: 'boolean', prompt: 'Do you use a CRM?')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)

    edit_evidence(offer, conversation, field_key: 'uses_crm', value: false)

    expect(response).to have_http_status(:success)
    expect(r09_qualification(offer).evidence_snapshot.fetch('uses_crm')).to include(
      'typed_value' => false, 'polarity' => 'negative', 'source' => 'human', 'conversation_id' => conversation.id
    )
    expect(response.parsed_body.fetch('evidence_records').first.fetch('normalized_value')).to include('typed_value' => false)
  end

  it 'does not expose another Offer through a human edit response' do
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Second Offer'))
    conversation = r09_conversation(offer: first)
    other = r09_conversation(offer: second)
    r09_receive(other, 'My budget is TZS 987654.')

    edit_evidence(first, conversation)

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('987654')
    expect(response.parsed_body.fetch('evidence_records').map { |fact| fact.fetch('offer_id') }.uniq).to eq([first.fetch('id')])
  end

  it 'rejects changing a used archived key when it is introduced again' do
    question = r09_question('revenue', answer_type: 'money', prompt: 'What is your monthly revenue?', period: 'month')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')
    r09_receive(conversation, 'TZS 1200000')
    r09_update_offer(offer, questions: [])
    expect(response).to have_http_status(:success)
    archived = response.parsed_body

    r09_update_offer(archived, questions: [question.merge('period' => 'year')])

    expect(response).to have_http_status(:unprocessable_entity)
    expect(r09_qualification(offer).evidence_snapshot.fetch('revenue')).to include('period' => 'month')
  end

  it 'rejects changing the currency of a money field already used by evidence' do
    offer = r09_create_offer(r09_configuration)
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'My budget is TZS 600000.')

    r09_update_offer(offer, currency: 'USD')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(AiLeadEmployee::Offer.find(offer.fetch('id')).currency).to eq('TZS')
  end
end
