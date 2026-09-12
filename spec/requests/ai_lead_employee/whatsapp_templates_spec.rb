# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WhatsApp templates', type: :request do
  def cloud_channel(account)
    create(:channel_whatsapp, account: account, provider_config: {}, sync_templates: false,
                              validate_provider_config: false).tap do |channel|
      channel.update_columns(provider: 'whatsapp_cloud', provider_config: { 'business_account_id' => 'waba-r26' }) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def draft_params(channel, body: 'Hello {{1}}, your order is ready.')
    {
      inbox_id: channel.inbox.id,
      name: 'order_update',
      language: 'en_US',
      category: 'UTILITY',
      body: body,
      variables: body.include?('{{1}}') ? [{ position: 1, example: 'Asha' }] : [],
      buttons: [{ type: 'QUICK_REPLY', text: 'Thanks' }]
    }
  end

  describe 'POST /api/v1/accounts/:account_id/whatsapp_templates' do
    it 'lets a business account admin save a locally validated draft without claiming Meta approval', :aggregate_failures do
      account = create(:account)
      admin = create(:user, :administrator, account: account)
      channel = cloud_channel(account)

      post "/api/v1/accounts/#{account.id}/whatsapp_templates",
           params: draft_params(channel),
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
      team_member = create(:user, account: account)
      other_channel = cloud_channel(other_account)

      post "/api/v1/accounts/#{account.id}/whatsapp_templates",
           params: { inbox_id: other_channel.inbox.id, name: 'cross_tenant', language: 'en_US', category: 'UTILITY', body: 'Nope' },
           headers: team_member.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'keeps tenant reads isolated even for administrators' do
      account = create(:account)
      other_account = create(:account)
      admin = create(:user, :administrator, account: account)
      other_admin = create(:user, :administrator, account: other_account)
      other_channel = cloud_channel(other_account)
      post "/api/v1/accounts/#{other_account.id}/whatsapp_templates", params: draft_params(other_channel),
                                                                      headers: other_admin.create_new_auth_token, as: :json
      template_id = response.parsed_body.fetch('id')

      get "/api/v1/accounts/#{account.id}/whatsapp_templates/#{template_id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'submits only the current immutable revision and rejects duplicate submission requests', :aggregate_failures do
      account = create(:account)
      admin = create(:user, :administrator, account: account)
      channel = cloud_channel(account)
      post "/api/v1/accounts/#{account.id}/whatsapp_templates", params: draft_params(channel),
                                                                headers: admin.create_new_auth_token, as: :json
      template = WhatsappTemplate.find(response.parsed_body.fetch('id'))
      first_revision = template.latest_revision
      patch "/api/v1/accounts/#{account.id}/whatsapp_templates/#{template.id}",
            params: draft_params(channel, body: 'Updated content'), headers: admin.create_new_auth_token, as: :json
      second_revision = template.reload.latest_revision

      expect do
        post "/api/v1/accounts/#{account.id}/whatsapp_templates/#{template.id}/submit",
             headers: admin.create_new_auth_token, as: :json
      end.to have_enqueued_job(Whatsapp::TemplateSubmissionJob).with(second_revision)
      expect(response).to have_http_status(:accepted)
      expect do
        post "/api/v1/accounts/#{account.id}/whatsapp_templates/#{template.id}/submit",
             headers: admin.create_new_auth_token, as: :json
      end.not_to have_enqueued_job(Whatsapp::TemplateSubmissionJob)
      expect(response).to have_http_status(:conflict)
      expect(first_revision.reload).to have_attributes(body: 'Hello {{1}}, your order is ready.', status: 'draft')
      expect(second_revision.reload).to have_attributes(body: 'Updated content', status: 'submission_pending')
    end

    it 'executes the asynchronous provider boundary with a stub and does not send a customer message' do
      account = create(:account)
      admin = create(:user, :administrator, account: account)
      channel = cloud_channel(account)
      post "/api/v1/accounts/#{account.id}/whatsapp_templates", params: draft_params(channel, body: 'Order ready'),
                                                                headers: admin.create_new_auth_token, as: :json
      template_id = response.parsed_body.fetch('id')
      provider_request = stub_request(:post, 'https://graph.facebook.com/v14.0/waba-r26/message_templates')
                         .to_return(status: 200, body: { id: 'meta-async' }.to_json,
                                    headers: { 'Content-Type' => 'application/json' })

      expect do
        perform_enqueued_jobs(only: Whatsapp::TemplateSubmissionJob) do
          post "/api/v1/accounts/#{account.id}/whatsapp_templates/#{template_id}/submit",
               headers: admin.create_new_auth_token, as: :json
        end
      end.not_to change(Message, :count)

      expect(provider_request).to have_been_requested.once
      expect(WhatsappTemplate.find(template_id).latest_revision).to have_attributes(status: 'submitted', provider_template_id: 'meta-async')
    end
  end
end
