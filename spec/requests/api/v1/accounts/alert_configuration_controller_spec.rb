# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Alert Configuration API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:operator) { create(:user, account: account, role: :agent, custom_attributes: { 'whatsapp_alert_phone' => '+255700000001' }) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_account_member) { create(:user, account: create(:account), role: :agent) }

  it 'lets an administrator configure a default owner and each authorized alert route' do
    patch "/api/v1/accounts/#{account.id}/alert_configuration",
          headers: admin.create_new_auth_token,
          params: {
            default_owner_id: operator.id,
            alert_routes: {
              highly_qualified_sales_handoff: [{ type: 'assignee' }, { type: 'member', user_id: operator.id }],
              booking_preparation: [{ type: 'assignee' }],
              human_review_request: [{ type: 'member', user_id: operator.id }],
              knowledge_approval: [{ type: 'admin' }]
            }
          }, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('default_owner')).to include('id' => operator.id, 'name' => operator.name)
    expect(response.parsed_body.dig('alert_routes', 'human_review_request')).to eq([{ 'type' => 'member', 'user_id' => operator.id }])
    expect(account.reload.settings.dig('ai_lead_employee', 'human_operator_id')).to eq(operator.id)
  end

  it 'rejects a route that names a user outside the Business Account' do
    patch "/api/v1/accounts/#{account.id}/alert_configuration",
          headers: admin.create_new_auth_token,
          params: { alert_routes: { human_review_request: [{ type: 'member', user_id: other_account_member.id }] } },
          as: :json

    expect(response).to have_http_status(:bad_request)
    expect(account.reload.settings.dig('ai_lead_employee', 'alert_routes')).to be_nil
  end

  it 'does not expose or let a Human Operator change Team and alerts settings' do
    get "/api/v1/accounts/#{account.id}/alert_configuration", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch "/api/v1/accounts/#{account.id}/alert_configuration",
          headers: agent.create_new_auth_token,
          params: { default_owner_id: operator.id }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(account.reload.settings.dig('ai_lead_employee', 'human_operator_id')).to be_nil
  end
end
