require 'rails_helper'

RSpec.describe '/api/v1/accounts/{account.id}/contacts/:id/conversations', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox_1) { create(:inbox, account: account) }
  let(:inbox_2) { create(:inbox, account: account) }
  let(:contact_inbox_1) { create(:contact_inbox, contact: contact, inbox: inbox_1) }
  let(:contact_inbox_2) { create(:contact_inbox, contact: contact, inbox: inbox_2) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:unknown) { create(:user, account: account, role: nil) }

  before do
    create(:inbox_member, user: agent, inbox: inbox_1)
    2.times.each do
      create(:conversation, account: account, inbox: inbox_1, contact: contact, contact_inbox: contact_inbox_1)
      create(:conversation, account: account, inbox: inbox_2, contact: contact, contact_inbox: contact_inbox_2)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/:id/conversations' do
    context 'when unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      context 'with user as administrator' do
        it 'returns conversations from all inboxes' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: admin.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 4
        end

        it 'loads consent once for up to 20 Conversations of the same contact' do
          16.times do
            create(:conversation, account: account, inbox: inbox_1, contact: contact, contact_inbox: contact_inbox_1)
          end
          opted_out_at = Time.zone.at(1_788_999_900)
          create(
            :lead_follow_up_opt_out,
            account: account,
            contact: contact,
            conversation: nil,
            reason: 'legacy_import',
            opted_out_at: opted_out_at
          )

          queries, payload = consent_queries do
            get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations",
                headers: admin.create_new_auth_token
          end

          expect(queries).to eq(2)
          expect(payload.size).to eq(20)
          expect(payload.pluck('automated_contact_consent')).to all(
            include(
              'state' => 'withdrawn',
              'evidence' => { 'legacy' => true, 'occurred_at' => opted_out_at.iso8601 }
            )
          )
        end
      end

      context 'with user as agent' do
        it 'returns conversations from the inboxes which agent has access to' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: agent.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 2
        end

        it 'keeps legacy evidence without a source Conversation hidden' do
          account.conversations.where(inbox: inbox_1).find_each { |conversation| conversation.update!(assignee: agent) }
          create(
            :lead_follow_up_opt_out,
            account: account,
            contact: contact,
            conversation: nil,
            reason: 'legacy_import'
          )

          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations",
              headers: agent.create_new_auth_token
          expect(response).to have_http_status(:success)
          consent = response.parsed_body.fetch('payload').first.fetch('automated_contact_consent')

          expect(consent).to include('state' => 'withdrawn', 'reason' => 'legacy_import')
          expect(consent).not_to have_key('evidence')
        end
      end

      context 'with user as unknown role' do
        it 'returns conversations from no inboxes' do
          get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: unknown.create_new_auth_token

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body

          expect(json_response['payload'].length).to eq 0
        end
      end
    end
  end

  def consent_queries(&)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      next unless payload[:sql].match?(/FROM "(?:lead_follow_up_opt_outs|lead_consent_events)"/)

      queries << payload[:sql]
    end
    ActiveRecord::Base.uncached(&)
    [queries.size, response.parsed_body.fetch('payload')]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
