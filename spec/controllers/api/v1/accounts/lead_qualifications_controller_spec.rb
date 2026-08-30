# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lead Qualifications API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }

  it 'lets an authorized Human Operator correct evidence and re-evaluates the Lead' do
    create(:qualification_evidence, account: account, contact: conversation.contact, signal: :budget, value: { 'value' => '$50' })

    post "/api/v1/accounts/#{account.id}/lead_qualifications/#{conversation.contact.id}/evidence",
         headers: agent.create_new_auth_token,
         params: { signal: 'budget', value: '$2500' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['evidence']['budget']['value']).to eq('$2500')
    expect(response.parsed_body['quality']).to eq('low_qualified')
    expect(QualificationEvidence.where(contact: conversation.contact, signal: :budget).current.count).to eq(1)
  end

  it 'shows an existing decision without re-evaluating it' do
    qualification = create(:lead_qualification, account: account, contact: conversation.contact, score: 10)
    evidence = create(
      :qualification_evidence,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      signal: :problem,
      value: { 'value' => 'need more leads' }
    )
    handoff = create(
      :lead_handoff,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification,
      alert_recipients: ['255700000001'],
      alert_deliveries: [{ 'recipient' => '255700000001', 'status' => 'queued', 'message_id' => 123 }]
    )

    expect do
      get "/api/v1/accounts/#{account.id}/lead_qualifications/#{conversation.contact.id}",
          headers: agent.create_new_auth_token,
          as: :json
    end.not_to(change { qualification.reload.last_evaluated_at })

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['score']).to eq(10)
    expect(response.parsed_body['evidence_records'].first).to include(
      'id' => evidence.id,
      'signal' => 'problem',
      'value' => 'need more leads',
      'source' => 'extracted',
      'source_reference' => include(
        'type' => 'message',
        'evidence_id' => evidence.id,
        'conversation_id' => conversation.id
      )
    )
    expect(response.parsed_body['evidence_records'].first).not_to include('source_message', 'user_name')
    expect(response.parsed_body['handoffs'].first).to include(
      'id' => handoff.id,
      'status' => 'open',
      'alert_deliveries' => [{ 'recipient' => '255700000001', 'status' => 'queued', 'message_id' => 123 }]
    )
  end

  it 'does not let an admin read a Lead from a different Business Account through the selected account' do
    other_account = create(:account)
    other_conversation = create(:conversation, account: other_account)
    create(:account_user, account: other_account, user: agent, role: :administrator)
    create(:lead_qualification, account: other_account, contact: other_conversation.contact, score: 99)

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{other_conversation.contact.id}",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'does not let a team member write evidence for a Lead from a different Business Account through the selected account' do
    other_account = create(:account)
    other_conversation = create(:conversation, account: other_account)
    create(:account_user, account: other_account, user: agent, role: :agent)

    post "/api/v1/accounts/#{account.id}/lead_qualifications/#{other_conversation.contact.id}/evidence",
         headers: agent.create_new_auth_token,
         params: { signal: 'budget', value: '$2500' },
         as: :json

    expect(response).to have_http_status(:not_found)
    expect(QualificationEvidence.where(contact: other_conversation.contact)).to be_empty
  end
end
