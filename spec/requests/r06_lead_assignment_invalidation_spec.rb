require 'rails_helper'

RSpec.describe 'Lead assignment access invalidation', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account, assignee: member) }
  let(:headers) { admin.create_new_auth_token }

  it 'tells both operators to clear open views when an Admin reassigns a Lead' do
    expected_event = { event: 'access.changed', data: { account_id: account.id } }
    old_recipient = member.pubsub_token
    new_recipient = colleague.pubsub_token
    auth_headers = headers

    expect do
      ActiveRecord::Base.transaction do
        expect do
          patch "/api/v1/accounts/#{account.id}/leads/#{conversation.contact_id}",
                headers: auth_headers, params: { lead: { assignee_id: colleague.id } }, as: :json
        end.not_to have_broadcasted_to(old_recipient).with(expected_event)
      end
    end.to have_broadcasted_to(old_recipient).with(expected_event)
                                             .and have_broadcasted_to(new_recipient).with(expected_event)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('assignee', 'id')).to eq(colleague.id)
  end

  it 'preserves access invalidation when assignment and qualification evidence are edited together' do
    expected_event = { event: 'access.changed', data: { account_id: account.id } }
    old_recipient = member.pubsub_token
    new_recipient = colleague.pubsub_token
    auth_headers = headers

    expect do
      patch "/api/v1/accounts/#{account.id}/leads/#{conversation.contact_id}",
            headers: auth_headers,
            params: { lead: { assignee_id: colleague.id, business_name: 'Demo workflow', evidence: { budget: '500 per month' } } },
            as: :json
    end.to have_broadcasted_to(old_recipient).with(expected_event)
                                             .and have_broadcasted_to(new_recipient).with(expected_event)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['business_name']).to eq('Demo workflow')
    expect(response.body).to include('500 per month')
  end

  it 'keeps both operators views valid when the Lead edit rolls back' do
    recipients = [member.pubsub_token, colleague.pubsub_token]
    auth_headers = headers
    previous_broadcasts = recipients.map { |recipient| ActionCable.server.pubsub.broadcasts(recipient).dup }

    ActiveRecord::Base.transaction do
      patch "/api/v1/accounts/#{account.id}/leads/#{conversation.contact_id}",
            headers: auth_headers, params: { lead: { assignee_id: colleague.id } }, as: :json
      expect(response).to have_http_status(:ok)
      raise ActiveRecord::Rollback
    end

    expect(recipients.map { |recipient| ActionCable.server.pubsub.broadcasts(recipient) }).to eq(previous_broadcasts)
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: member.create_new_auth_token
    expect(response).to have_http_status(:ok)
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: colleague.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end
end
