require 'rails_helper'

RSpec.describe 'Assigned Team Member access', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:assigned) { create(:conversation, account: account, inbox: inbox, assignee: member, status: :open) }
  let!(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: colleague, status: :open) }
  let(:headers) { member.create_new_auth_token }

  before { create(:inbox_member, inbox: inbox, user: member) }

  def account_path(path)
    "/api/v1/accounts/#{account.id}/#{path}"
  end

  it 'shows only assigned Conversations, even within a shared inbox, and removes access after reassignment' do
    get account_path("conversations/#{assigned.display_id}"), headers: headers
    expect(response).to have_http_status(:ok)
    get account_path("conversations/#{unassigned.display_id}"), headers: headers
    expect(response).to have_http_status(:unauthorized)

    get account_path('conversations'), params: { status: 'open' }, headers: headers
    expect(response.parsed_body.dig('data', 'payload').pluck('id')).to eq([assigned.display_id])
    expect(response.parsed_body.dig('data', 'meta', 'all_count')).to eq(1)

    post account_path("conversations/#{assigned.display_id}/assignments"),
         headers: admin.create_new_auth_token, params: { assignee_id: colleague.id }, as: :json
    expect(response).to have_http_status(:ok)
    get account_path("conversations/#{assigned.display_id}"), headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not expose an unrelated Lead through directories, nested resources or global search' do
    unassigned.contact.update!(name: 'Secret unrelated buyer')
    %W[contacts/#{unassigned.contact_id} leads/#{unassigned.contact_id}
       contacts/#{unassigned.contact_id}/notes contacts/#{unassigned.contact_id}/conversations
       contacts/#{unassigned.contact_id}/attachments lead_qualifications/#{unassigned.contact_id}].each do |path|
      get account_path(path), headers: headers
      expect(response.status).to be_in([401, 404]), path
    end
    %w[contacts leads search].each do |path|
      get account_path(path), params: { q: 'Secret unrelated buyer' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Secret unrelated buyer')
    end
    patch account_path("contacts/#{assigned.contact_id}"), headers: headers, params: { name: 'Permitted edit' }, as: :json
    expect(response).to have_http_status(:ok)
    get account_path("contacts/#{assigned.contact_id}"), headers: headers
    expect(response.body).to include('Permitted edit')
  end

  it 'withholds combined Qualification and unrelated history for a Lead with differently assigned Conversations' do # rubocop:disable RSpec/MultipleExpectations
    unassigned.update!(contact: assigned.contact, contact_inbox: assigned.contact_inbox)
    create(:message, conversation: unassigned, account: account, inbox: inbox, content: 'Hidden budget 987654')
    create(:lead_qualification, account: account, contact: assigned.contact, quality: :highly_qualified,
                                reasons: ['Hidden budget 987654'],
                                evidence_snapshot: { budget: { value: 'Hidden budget 987654', conversation_id: unassigned.id } })

    booking = create(:booking, account: account, contact: assigned.contact, conversation: assigned,
                               lead_qualification: assigned.contact.lead_qualification,
                               qualification_snapshot: { evidence: { budget: { value: 'Hidden budget 987654' } } },
                               calendar_event_payload: { preparation_brief: 'Hidden budget 987654' })
    get account_path('bookings'), params: { from: booking.starts_at.iso8601 }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Hidden budget 987654')

    %W[conversations/#{assigned.display_id} leads/#{assigned.contact_id} lead_qualifications/#{assigned.contact_id}].each do |path|
      get account_path(path), headers: headers
      expect(response).to have_http_status(:ok), path
      expect(response.body).not_to include('Hidden budget 987654'), path
    end
    get account_path('inbox_conversations'), params: { queue: 'hot' }, headers: headers
    expect(response.parsed_body['total']).to eq(0)
    get account_path("contacts/#{assigned.contact_id}/conversations"), headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq([assigned.display_id])
    get account_path('search'), params: { q: 'Hidden budget 987654' }, headers: headers
    expect(response.body).not_to include('Hidden budget 987654')

    get account_path("conversations/#{assigned.display_id}"), headers: admin.create_new_auth_token
    expect(response.body).to include('Hidden budget 987654')
  end

  it 'permits assigned replies and notes but reserves assignment, creation, exports and settings to Admins' do
    post account_path("conversations/#{assigned.display_id}/messages"),
         headers: headers,
         params: { content: 'Permitted private note', private: true, message_type: 'outgoing' }, as: :json
    expect(response).to have_http_status(:ok)
    post account_path("conversations/#{assigned.display_id}/messages"),
         headers: headers,
         params: { content: 'Permitted reply', private: false, message_type: 'outgoing' }, as: :json
    expect(response).to have_http_status(:ok)
    post account_path("conversations/#{unassigned.display_id}/messages"),
         headers: headers,
         params: { content: 'Forbidden reply', message_type: 'outgoing' }, as: :json
    expect(response).to have_http_status(:unauthorized)

    post account_path("conversations/#{assigned.display_id}/assignments"),
         headers: headers,
         params: { assignee_id: colleague.id }, as: :json
    expect(response).to have_http_status(:unauthorized)
    post account_path('leads/export'), headers: headers
    expect(response).to have_http_status(:unauthorized)
    post account_path('contacts/export'), headers: headers
    expect(response).to have_http_status(:unauthorized)
    %w[ai_provider_connection knowledge_items qualification_configuration evaluation_sandbox].each do |path|
      get account_path(path), headers: headers
      expect(response.status).to be_in([401, 404]), path
    end
  end

  it 'scopes reviews, bookings, notifications, account settings and direct evidence edits' do
    review = create(:human_review_request, account: account, conversation: unassigned, question: 'Hidden review question')
    create(:notification, account: account, user: member, primary_actor: unassigned)
    booking = create(:booking, account: account, contact: unassigned.contact, conversation: unassigned, assignee: member)
    account.update!(settings: { ai_lead_employee: { internal_business_rule: 'Hidden business rule' } })

    get account_path("human_review_requests/#{review.id}"), headers: headers
    expect(response.status).to be_in([401, 404])
    get account_path('human_review_requests'), headers: headers
    expect(response.body).not_to include('Hidden review question')
    get account_path('bookings'), headers: headers
    expect(response.parsed_body['bookings']).to eq([])
    post account_path("bookings/#{booking.id}/cancel"), headers: headers, params: { reason: 'not allowed' }, as: :json
    expect(response.status).to be_in([401, 404])
    get account_path('notifications'), headers: headers
    expect(response.parsed_body.dig('data', 'payload')).to eq([])
    get "/api/v1/accounts/#{account.id}", headers: headers
    expect(response.body).not_to include('Hidden business rule')
    post account_path("lead_qualifications/#{unassigned.contact_id}/evidence"),
         headers: headers,
         params: { signal: 'problem', value: 'forbidden edit' }, as: :json
    expect(response.status).to be_in([401, 404])
  end

  it 'keeps unread counts and filter results assigned-only immediately after reassignment' do
    account.enable_features!(:conversation_unread_counts, :unread_count_for_filters)
    create(:message, account: account, conversation: assigned, message_type: :incoming)
    create(:message, account: account, conversation: unassigned, message_type: :incoming)
    get account_path('conversations/unread_counts'), headers: headers
    expect(response.parsed_body.dig('payload', 'all_count')).to eq(1)
    assigned.update!(assignee: colleague)
    get account_path('conversations/unread_counts'), headers: headers
    expect(response.parsed_body.dig('payload', 'all_count')).to eq(0)
  end

  it 'excludes mixed-access Qualification from the legacy dashboard counts' do
    create(:conversation, account: account, contact: assigned.contact, assignee: colleague)
    create(:lead_qualification, account: account, contact: assigned.contact, quality: :highly_qualified)
    get account_path('operational_dashboard'), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('performance', 'highly_qualified_leads')).to eq(0)
  end

  it 'loads an assigned Inbox without exposing its settings or another contact channel' do
    assigned
    InboxMember.where(user: member, inbox: inbox).destroy_all
    inbox.update!(greeting_message: 'Admin-only greeting configuration')
    hidden_inbox = create(:inbox, account: account, name: 'Hidden source')
    hidden_contact_inbox = create(:contact_inbox, contact: assigned.contact, inbox: hidden_inbox, source_id: 'hidden-source-identifier')
    get account_path("inboxes/#{inbox.id}"), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Admin-only greeting configuration')
    get account_path('inboxes'), headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq([inbox.id])
    get account_path("contacts/#{assigned.contact_id}"), headers: headers
    expect(response.body).not_to include(hidden_contact_inbox.source_id, 'Hidden source')
  end
end
