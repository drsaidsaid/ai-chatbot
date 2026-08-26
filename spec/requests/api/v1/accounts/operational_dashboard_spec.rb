# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Operational Dashboard API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/operational_dashboard' do
    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/operational_dashboard"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the owned dashboard payload for an authenticated Human Operator' do
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)
      create(:lead_qualification, account: account, contact: contact, quality: :qualified)

      get "/api/v1/accounts/#{account.id}/operational_dashboard",
          headers: agent.create_new_auth_token,
          params: { quality: 'qualified' },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['leads'].first).to include(
        'id' => contact.id,
        'quality' => 'qualified',
        'conversation_display_id' => conversation.display_id
      )
      expect(response.parsed_body['queues']).to be_present
      expect(response.parsed_body['performance']).to be_present
    end
  end
end
