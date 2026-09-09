require 'rails_helper'

RSpec.describe 'First Team Member assignment', type: :request do
  it 'offers current account members before their first assignment, then grants only that Lead' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    member = create(:user, account: account, role: :agent)
    create(:user, account: create(:account), role: :agent)
    conversation = create(:conversation, account: account, assignee: nil)
    admin_headers = admin.create_new_auth_token
    member_headers = member.create_new_auth_token
    base = "/api/v1/accounts/#{account.id}"

    get "#{base}/leads", headers: admin_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('filter_options', 'assignees').pluck('id')).to contain_exactly(admin.id, member.id)
    get "#{base}/leads", headers: member_headers
    expect(response.parsed_body['leads']).to be_empty
    expect(response.parsed_body.dig('filter_options', 'assignees')).to be_empty

    patch "#{base}/leads/#{conversation.contact_id}", headers: admin_headers,
                                                      params: { lead: { assignee_id: member.id } }, as: :json
    expect(response).to have_http_status(:ok)
    get "#{base}/leads", headers: member_headers
    expect(response.parsed_body['leads'].pluck('id')).to eq([conversation.contact_id])

    delete "#{base}/agents/#{member.id}", headers: admin_headers
    get "#{base}/leads", headers: admin_headers
    expect(response.parsed_body.dig('filter_options', 'assignees').pluck('id')).to eq([admin.id])
  end
end
