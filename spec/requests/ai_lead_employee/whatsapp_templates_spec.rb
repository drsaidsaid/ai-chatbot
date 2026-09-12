# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WhatsApp templates', type: :request do
  describe 'POST /api/v1/accounts/:account_id/whatsapp_templates' do
    it 'lets a business account admin save a locally validated draft without claiming Meta approval', :aggregate_failures do
      account = create(:account)
      admin = create(:user, :administrator, account: account)
      channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false,
                                          validate_provider_config: false)

      post "/api/v1/accounts/#{account.id}/whatsapp_templates",
           params: {
             inbox_id: channel.inbox.id,
             name: 'order_update',
             language: 'en_US',
             category: 'UTILITY',
             body: 'Hello {{1}}, your order is ready.',
             variables: [{ position: 1, example: 'Asha' }],
             buttons: [{ type: 'QUICK_REPLY', text: 'Thanks' }]
           },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        'name' => 'order_update',
        'status' => 'draft',
        'meta_approval' => 'not_submitted'
      )
      expect(response.parsed_body.fetch('preview')).to include('body' => 'Hello {{1}}, your order is ready.')
    end

    it 'does not let a team member create or read another business account template' do
      account = create(:account)
      other_account = create(:account)
      team_member = create(:user, :agent, account: account)
      other_channel = create(:channel_whatsapp, account: other_account, provider: 'whatsapp_cloud', sync_templates: false,
                                                validate_provider_config: false)

      post "/api/v1/accounts/#{account.id}/whatsapp_templates",
           params: { inbox_id: other_channel.inbox.id, name: 'cross_tenant', language: 'en_US', category: 'UTILITY', body: 'Nope' },
           headers: team_member.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
