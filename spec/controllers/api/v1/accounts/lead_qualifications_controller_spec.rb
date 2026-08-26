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

    expect do
      get "/api/v1/accounts/#{account.id}/lead_qualifications/#{conversation.contact.id}",
          headers: agent.create_new_auth_token,
          as: :json
    end.not_to(change { qualification.reload.last_evaluated_at })

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['score']).to eq(10)
  end
end
