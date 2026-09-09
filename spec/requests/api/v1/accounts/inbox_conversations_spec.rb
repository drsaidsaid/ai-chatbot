require 'rails_helper'

RSpec.describe 'Inbox conversations', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Grace Mrema') }

  def fetch_inbox(params = {}, user = admin, requested_account = account)
    get "/api/v1/accounts/#{requested_account.id}/inbox_conversations",
        params: params, headers: user.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'lists each Conversation, including inquiries without Qualification, with scoped counts' do
    first = create(:conversation, account: account, inbox: inbox, contact: contact)
    second = create(:conversation, account: account, inbox: inbox, contact: contact)
    create(:conversation)
    result = fetch_inbox

    expect(response).to have_http_status(:ok)
    expect(result['conversations'].pluck('conversation_display_id')).to contain_exactly(first.display_id, second.display_id)
    expect(result['conversations'].pluck('quality')).to eq(%w[unknown unknown])
    expect(result['counts']).to eq('all' => 2, 'review' => 0, 'hot' => 0)
    expect(result['total']).to eq(2)
  end

  it 'applies search and filters to Conversations without leaking hidden rows or counts' do
    agent = create(:user, account: account, role: :agent)
    create(:inbox_member, user: agent, inbox: inbox)
    visible = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent)
    sibling = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent)
    hidden = create(:conversation, account: account)
    create(:human_review_request, account: account, conversation: visible)
    create(:human_review_request, account: account, conversation: visible)
    create(:human_review_request, account: account, conversation: hidden)
    create(:lead_qualification, account: account, contact: contact, quality: :highly_qualified)
    create(:message, account: account, inbox: inbox, conversation: visible, content: 'Need a solar assessment')
    create(:message, account: account, inbox: inbox, conversation: sibling, content: 'Private marker', private: true)
    result = fetch_inbox({ queue: 'review' }, agent)
    expect(result['conversations'].pluck('conversation_display_id')).to eq([visible.display_id])
    expect(result['counts']).to eq('all' => 2, 'review' => 1, 'hot' => 2)
    expect(fetch_inbox({ q: 'solar' }, agent)['total']).to eq(1)
    expect(fetch_inbox({ q: 'Private marker' }, agent)['total']).to eq(0)
    expect(fetch_inbox({ q: 'Grace' }, agent)['total']).to eq(2)
    expect(fetch_inbox({ source_id: hidden.inbox_id }, agent)['total']).to eq(0)
    expect(fetch_inbox({ source_id: hidden.inbox_id }, agent)['counts']).to eq('all' => 0, 'review' => 0, 'hot' => 0)
  end

  it 'filters actual booked Conversations and pending due follow-ups independently of Lead qualification state' do
    first = create(:conversation, account: account, inbox: inbox, contact: contact)
    second = create(:conversation, account: account, inbox: inbox, contact: contact)
    qualification = create(:lead_qualification, account: account, contact: contact, quality: :qualified)
    create(:booking, account: account, contact: contact, conversation: first, lead_qualification: qualification)
    create(:lead_follow_up, account: account, contact: contact, conversation: second,
                            lead_qualification: qualification, scheduled_at: 5.minutes.ago)
    expect(fetch_inbox(booking_status: 'booked')['conversations'].pluck('conversation_display_id')).to eq([first.display_id])
    expect(fetch_inbox(follow_up_status: 'due')['conversations'].pluck('conversation_display_id')).to eq([second.display_id])
    expect(fetch_inbox(booking_status: 'booked', follow_up_status: 'due')['total']).to eq(0)
  end

  it 'paginates in stable activity order and excludes operator alert plumbing' do
    conversations = create_list(:conversation, 26, account: account, inbox: inbox, contact: contact, last_activity_at: 1.hour.ago)
    create(:conversation, account: account, inbox: inbox,
                          additional_attributes: { ai_lead_employee_alert_conversation: true })
    first_page = fetch_inbox
    second_page = fetch_inbox(page: 2)
    expect(first_page['total']).to eq(26)
    expect(first_page['pages']).to eq(2)
    expect(first_page['conversations'].size).to eq(25)
    expect(second_page['conversations'].pluck('conversation_display_id')).to eq([conversations.first.display_id])
    expect(fetch_inbox(page: 999)['page']).to eq(2)
  end

  it 'requires an authenticated Business Account membership' do
    get "/api/v1/accounts/#{account.id}/inbox_conversations"
    expect(response).to have_http_status(:unauthorized)
    fetch_inbox({}, admin, create(:account))
    expect(response).to have_http_status(:unauthorized)
  end
end
