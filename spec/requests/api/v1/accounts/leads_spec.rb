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
          params: { q: 'pricing', quality: 'qualified', sort: 'score', direction: 'desc', lead_id: contact.id },
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
      expect(response.parsed_body['selected_lead']).to include(
        'quality' => 'qualified',
        'conversation' => include('status' => 'open'),
        'detail' => include('qualification' => include('follow_up_state' => 'no_follow_up'))
      )
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

    it 'returns validation errors instead of silently retaining an invalid phone edit' do
      contact = create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi')

      patch "/api/v1/accounts/#{account.id}/leads/#{contact.id}",
            headers: admin.create_new_auth_token,
            params: { lead: { name: 'Jane Nkosi', phone_number: '123' } },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/phone/i)
      expect(contact.reload.phone_number).not_to eq('123')
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
        assignee: operator,
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
    it 'rejects files above the 100-row bounded apply limit during preview' do
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number\n")
      101.times { |index| file.write("Lead #{index},+2557#{index.to_s.rjust(8, '0')}\n") }
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error_key']).to eq('import_too_many_rows')
    ensure
      file&.close
      file&.unlink
    end

    it 'previews validation errors without writing' do
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number,business_name\nImported Lead,+255713456789,Imported Co\nBroken Lead,not-a-phone,Broken Co\n")
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['import']).to include(
        'status' => 'invalid',
        'create_count' => 1,
        'error_count' => 1,
        'can_apply' => false
      )
      expect(response.parsed_body.dig('import', 'rows')).to include(
        hash_including('line' => 3, 'action' => 'error', 'errors' => include(a_string_matching(/phone/i)))
      )
      expect(account.contacts.where(name: 'Imported Lead')).not_to exist
    ensure
      file&.close
      file&.unlink
    end

    it 'applies the unchanged valid file only after preview' do
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number,business_name\nImported Lead,+255713456789,Imported Co\n")
      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }
      digest = response.parsed_body.dig('import', 'digest')

      expect(response.parsed_body['import']).to include(
        'status' => 'ready', 'create_count' => 1, 'update_count' => 0, 'can_apply' => true
      )
      expect(account.contacts.where(name: 'Imported Lead')).not_to exist

      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: {
             import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
             mode: 'apply', preview_digest: digest
           }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['import']).to include('status' => 'completed', 'imported_count' => 1)
      expect(account.contacts.find_by!(phone_number: '+255713456789')).to have_attributes(name: 'Imported Lead')
    ensure
      file&.close
      file&.unlink
    end

    it 'refuses ambiguous identities and a file changed after preview' do
      phone_match = create(:contact, account: account, name: 'Phone Match', phone_number: '+255713456780')
      email_match = create(:contact, account: account, name: 'Email Match', email: 'lead@example.com')
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number,email\nAmbiguous,+255713456780,lead@example.com\n")
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }

      expect(response.parsed_body['import']).to include('status' => 'invalid', 'can_apply' => false)
      expect(response.parsed_body.dig('import', 'rows', 0)).to include('action' => 'ambiguous')
      expect(phone_match.reload.email).to be_blank
      expect(email_match.reload.phone_number).to be_blank

      file.rewind
      file.truncate(0)
      file.write("name,phone_number\nSafe,+255713456781\n")
      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }
      digest = response.parsed_body.dig('import', 'digest')
      file.rewind
      file.truncate(0)
      file.write("name,phone_number\nChanged,+255713456782\n")
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: {
             import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
             mode: 'apply', preview_digest: digest
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error_key']).to eq('import_file_changed')
      expect(account.contacts.where(name: 'Changed')).not_to exist
    ensure
      file&.close
      file&.unlink
    end

    it 'shows an existing Lead update before applying it and records audit history' do # rubocop:disable RSpec/MultipleExpectations
      contact = create(:contact, account: account, name: 'Old Name', phone_number: '+255713456783')
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number,business_name\nUpdated Name,+255713456783,Updated Co\n")
      file.rewind

      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }
      digest = response.parsed_body.dig('import', 'digest')

      expect(response.parsed_body['import']).to include('create_count' => 0, 'update_count' => 1, 'can_apply' => true)
      expect(response.parsed_body.dig('import', 'rows', 0)).to include(
        'action' => 'update', 'existing_lead_id' => contact.id
      )
      expect(contact.reload.name).to eq('Old Name')

      workflow_counts = [
        Conversation.count,
        LeadQualification.count,
        QualificationEvidence.count,
        AiLeadEmployee::AiProviderUsage.count,
        HumanReviewRequest.count
      ]
      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: {
             import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
             mode: 'apply', preview_digest: digest
           }

      expect(response).to have_http_status(:success)
      expect(contact.reload).to have_attributes(name: 'Updated Name')
      expect(contact.additional_attributes['company_name']).to eq('Updated Co')
      expect(Audited::Audit.where(auditable: contact).last.audited_changes).to include(
        'ai_lead_employee_action' => 'lead_edit'
      )
      expect([Conversation.count,
              LeadQualification.count,
              QualificationEvidence.count,
              AiLeadEmployee::AiProviderUsage.count,
              HumanReviewRequest.count]).to eq(workflow_counts)
    ensure
      file&.close
      file&.unlink
    end # rubocop:enable RSpec/MultipleExpectations

    it 'revalidates identity resolution when applying a previously safe preview' do
      file = Tempfile.new(['leads', '.csv'])
      file.write("name,phone_number\nPreviewed Lead,+255713456784\n")
      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: { import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'), mode: 'preview' }
      digest = response.parsed_body.dig('import', 'digest')
      concurrent = create(:contact, account: account, name: 'Concurrent Lead', phone_number: '+255713456784')

      file.rewind
      post "/api/v1/accounts/#{account.id}/leads/import",
           headers: admin.create_new_auth_token,
           params: {
             import_file: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
             mode: 'apply', preview_digest: digest
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error_key']).to eq('import_file_changed')
      expect(concurrent.reload.name).to eq('Concurrent Lead')
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
      expect(response.headers['Cache-Control']).to eq('private, no-store')
      expect(response.body).to include('id,name,phone_number,email,business_name,quality,score')
      expect(response.body).to include('Jane Nkosi')
    end

    it 'exports only Leads matching the current filters' do
      matching = create(:contact, :with_phone_number, account: account, name: 'Matching Lead')
      excluded = create(:contact, :with_phone_number, account: account, name: 'Excluded Lead')
      create(:conversation, account: account, inbox: inbox, contact: matching)
      create(:conversation, account: account, inbox: inbox, contact: excluded)
      create(:lead_qualification, account: account, contact: matching, quality: :qualified)
      create(:lead_qualification, account: account, contact: excluded, quality: :unqualified)

      post "/api/v1/accounts/#{account.id}/leads/export",
           headers: admin.create_new_auth_token,
           params: { quality: 'qualified' },
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Matching Lead')
      expect(response.body).not_to include('Excluded Lead')
    end

    it 'refuses a Team Member export' do
      create(:inbox_member, user: operator, inbox: inbox)
      assigned = create(:contact, :with_phone_number, account: account, name: 'Assigned Export Lead')
      hidden = create(:contact, :with_phone_number, account: account, name: 'Hidden Export Lead')
      create(:conversation, account: account, inbox: inbox, contact: assigned, assignee: operator)
      create(:conversation, account: account, inbox: hidden_inbox, contact: hidden)

      post "/api/v1/accounts/#{account.id}/leads/export",
           headers: operator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('Assigned Export Lead', 'Hidden Export Lead')
    end

    it 'does not truncate a large filtered export at the directory page limit' do
      now = Time.current
      rows = Array.new(1001) do |index|
        {
          account_id: account.id,
          name: "Export Lead #{index}",
          phone_number: "+2557#{index.to_s.rjust(8, '0')}",
          created_at: now,
          updated_at: now
        }
      end
      Contact.insert_all!(rows) # rubocop:disable Rails/SkipsModelValidations -- large export fixture; request validates exported behavior

      post "/api/v1/accounts/#{account.id}/leads/export",
           headers: admin.create_new_auth_token,
           params: { q: 'Export Lead' },
           as: :json

      expect(response).to have_http_status(:success)
      expect(CSV.parse(response.body, headers: true).length).to eq(1001)
    end
  end
end
