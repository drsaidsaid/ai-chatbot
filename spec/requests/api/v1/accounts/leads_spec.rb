# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Leads API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:hidden_whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox.tap { |record| record.update!(name: 'WhatsApp sales') } }
  let(:hidden_inbox) { hidden_whatsapp_channel.inbox.tap { |record| record.update!(name: 'Hidden source') } }

  describe 'GET /api/v1/accounts/{account.id}/leads' do
    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/leads"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns paginated tenant-scoped Leads payloads' do
      contact = create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi',
                                                     additional_attributes: { 'company_name' => 'Nuru Boutique' })
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: operator)
      create(:message, account: account, inbox: inbox, conversation: conversation, content: 'Need pricing for a WhatsApp demo.')
      create(:lead_qualification, account: account, contact: contact, quality: :qualified, score: 78)

      get "/api/v1/accounts/#{account.id}/leads",
          headers: admin.create_new_auth_token,
          params: { q: 'pricing', quality: 'qualified', sort: 'score', direction: 'desc' },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['leads'].first).to include(
        'id' => contact.id,
        'name' => 'Jane Nkosi',
        'business_name' => 'Nuru Boutique',
        'quality' => 'qualified',
        'score' => 78
      )
      preview = response.parsed_body['selected_lead']['detail']['conversation_summary']['last_message_preview']
      expect(preview).to eq('Need pricing for a WhatsApp demo.')
      expect(response.parsed_body['filter_options']).to be_present
      expect(response.parsed_body['meta']).to include('page' => 1, 'per_page' => 25)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/leads/{id}' do
    it 'updates editable fields, records audit history, and recomputes qualification' do
      contact = create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi')
      create(:conversation, account: account, inbox: inbox, contact: contact)
      create(:lead_qualification, account: account, contact: contact, quality: :unknown)

      patch "/api/v1/accounts/#{account.id}/leads/#{contact.id}",
            headers: admin.create_new_auth_token,
            params: {
              lead: {
                name: 'Jane Nkosi',
                business_name: 'Nuru Boutique',
                evidence: {
                  problem: 'book demos automatically',
                  budget: '$500 per month',
                  urgency: 'this week',
                  decision_authority: 'owner'
                }
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['quality']).to eq('highly_qualified')
      expect(response.parsed_body['business_name']).to eq('Nuru Boutique')
      expect(Audited::Audit.where(auditable: contact).last.audited_changes).to include('ai_lead_employee_action' => 'lead_edit')
    end

    it 'returns validation errors for invalid phone or required fields' do
      contact = create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi')

      patch "/api/v1/accounts/#{account.id}/leads/#{contact.id}",
            headers: admin.create_new_auth_token,
            params: { lead: { name: '', phone_number: '123' } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include("Name can't be blank")
    end

    it 'prevents Human Operators from updating Leads outside their visible conversations' do
      create(:inbox_member, user: operator, inbox: inbox)
      hidden_contact = create(:contact, :with_phone_number, account: account, name: 'Hidden Lead')
      create(:conversation, account: account, inbox: hidden_inbox, contact: hidden_contact)

      patch "/api/v1/accounts/#{account.id}/leads/#{hidden_contact.id}",
            headers: operator.create_new_auth_token,
            params: { lead: { name: 'Updated Hidden Lead' } },
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(hidden_contact.reload.name).to eq('Hidden Lead')
    end

    it 'applies operator evidence edits to the visible conversation, not a newer hidden conversation' do
      create(:inbox_member, user: operator, inbox: inbox)
      contact = create(:contact, :with_phone_number, account: account, name: 'Shared Lead')
      visible_conversation = create(
        :conversation,
        account: account,
        inbox: inbox,
        contact: contact,
        last_activity_at: 2.hours.ago
      )
      hidden_conversation = create(
        :conversation,
        account: account,
        inbox: hidden_inbox,
        contact: contact,
        last_activity_at: 1.hour.ago
      )
      create(:lead_qualification, account: account, contact: contact, quality: :unknown)

      patch "/api/v1/accounts/#{account.id}/leads/#{contact.id}",
            headers: operator.create_new_auth_token,
            params: { lead: { evidence: { problem: 'qualify visible sales leads' } } },
            as: :json

      expect(response).to have_http_status(:success)
      expect(QualificationEvidence.where(conversation: visible_conversation, signal: :problem)).to exist
      expect(QualificationEvidence.where(conversation: hidden_conversation, signal: :problem)).not_to exist
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/leads/{id}' do
    it 'prevents Human Operators from reading Leads outside their visible conversations' do
      create(:inbox_member, user: operator, inbox: inbox)
      hidden_contact = create(:contact, :with_phone_number, account: account, name: 'Hidden Lead')
      create(:conversation, account: account, inbox: hidden_inbox, contact: hidden_contact)

      get "/api/v1/accounts/#{account.id}/leads/#{hidden_contact.id}",
          headers: operator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/leads/import' do
    it 'returns visible partial-import failure state' do
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number,business_name\nImported Lead,+255713456789,Imported Co\nBroken Lead,not-a-phone,Broken Co\n")
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['import']).to include(
        'status' => 'partial',
        'imported_count' => 1,
        'failed_count' => 1
      )
    ensure
      file&.close
      file&.unlink
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/leads/export' do
    it 'exports the owned Lead data shape as CSV' do
      contact = create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi')
      create(:conversation, account: account, inbox: inbox, contact: contact)
      create(:lead_qualification, account: account, contact: contact, quality: :qualified, score: 78)

      post "/api/v1/accounts/#{account.id}/leads/export",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('text/csv')
      expect(response.body).to include('id,name,phone_number,email,business_name,quality,score')
      expect(response.body).to include('Jane Nkosi')
    end
  end
end
