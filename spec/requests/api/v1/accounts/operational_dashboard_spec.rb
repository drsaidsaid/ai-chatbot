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
      contact = create(
        :contact,
        account: account,
        additional_attributes: {
          'city' => 'Dar es Salaam',
          'country' => 'Tanzania'
        }
      )
      conversation = create(
        :conversation,
        account: account,
        contact: contact,
        agent_last_seen_at: 2.hours.ago,
        status: :open,
        control_state: :ai_active
      )
      create(
        :message,
        account: account,
        inbox: conversation.inbox,
        conversation: conversation,
        content: 'I need help qualifying WhatsApp leads.',
        created_at: 1.hour.ago
      )
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
        'conversation_display_id' => conversation.display_id,
        'conversation_status' => 'open',
        'control_state' => 'ai_active',
        'last_message_preview' => 'I need help qualifying WhatsApp leads.',
        'location' => 'Dar es Salaam, Tanzania',
        'unread_count' => 1
      )
      expect(response.parsed_body['queues']).to be_present
      expect(response.parsed_body['performance']).to be_present
    end

    it 'keeps queue rows tenant-scoped and limited to the operator visible conversations' do
      other_account = create(:account)
      visible_contact = create(:contact, account: account)
      hidden_contact = create(:contact, account: account)
      other_contact = create(:contact, account: other_account)
      visible_conversation = create(:conversation, account: account, contact: visible_contact)
      create(:conversation, account: account, contact: hidden_contact)
      other_conversation = create(:conversation, account: other_account, contact: other_contact)
      create(:inbox_member, user: agent, inbox: visible_conversation.inbox)
      create(:lead_qualification, account: account, contact: visible_contact, quality: :qualified)
      create(:lead_qualification, account: account, contact: hidden_contact, quality: :highly_qualified)
      create(:lead_qualification, account: other_account, contact: other_contact, quality: :qualified)

      get "/api/v1/accounts/#{account.id}/operational_dashboard",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['leads'].pluck('id')).to eq([visible_contact.id])
      expect(response.parsed_body['leads'].pluck('id')).not_to include(hidden_contact.id, other_contact.id)
      expect(other_conversation.account_id).to eq(other_account.id)
    end
  end
end
