require 'rails_helper'

RSpec.describe 'Owned Team Member invitation', type: :request do
  around do |example|
    with_modified_env('SMTP_ADDRESS' => 'smtp.example.test') { example.run }
  end

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:password) { 'Local-member-Password1!' }

  def invite
    perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
      post "/api/v1/accounts/#{account.id}/agents",
           headers: admin.create_new_auth_token,
           params: { agent: { name: 'Invited member', email: 'r06-invited@example.test', role: 'agent' } }, as: :json
    end
    expect(response).to have_http_status(:ok)
    mail = ActionMailer::Base.deliveries.find { |item| item.to.include?('r06-invited@example.test') }
    expect(mail).to be_present
    CGI.unescapeHTML(mail.body.decoded).match(/reset_password_token=([^"&<>]+)/)[1]
  end

  it 'accepts the local invitation, signs in, and revokes only the selected Business Account' do
    token = invite
    put '/auth/password', params: { reset_password_token: token, password: password, password_confirmation: password }, as: :json
    expect(response).to have_http_status(:ok)
    post '/auth/sign_in', params: { email: 'r06-invited@example.test', password: password }, as: :json
    expect(response).to have_http_status(:ok)
    session_headers = response.headers.slice('access-token', 'client', 'uid')
    member_id = response.parsed_body.dig('data', 'id')
    other_account = create(:account)
    create(:account_user, account: other_account, user_id: member_id, role: :agent)

    get "/api/v1/accounts/#{account.id}/inbox_conversations", headers: session_headers
    expect(response).to have_http_status(:ok)
    delete "/api/v1/accounts/#{account.id}/agents/#{member_id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    get "/api/v1/accounts/#{account.id}/inbox_conversations", headers: session_headers
    expect(response).to have_http_status(:unauthorized)
    get "/api/v1/accounts/#{other_account.id}/inbox_conversations", headers: session_headers
    expect(response).to have_http_status(:ok)

    put '/auth/password', params: { reset_password_token: token, password: password, password_confirmation: password }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects expired invitation credentials' do
    token = invite
    travel 8.days do
      put '/auth/password', params: { reset_password_token: token, password: password, password_confirmation: password }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      post '/auth/sign_in', params: { email: 'r06-invited@example.test', password: password }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'reinvites a revoked member and retains separate notification preferences for each Business Account' do
    member = create(:user, account: account, role: :agent)
    other_account = create(:account)
    create(:account_user, account: other_account, user: member, role: :agent)
    member_headers = member.create_new_auth_token
    admin_headers = admin.create_new_auth_token
    preferences = {}

    [account, other_account].each_with_index do |business, index|
      patch "/api/v1/accounts/#{business.id}/notification_settings", headers: member_headers,
                                                                     params: { notification_settings: {
                                                                       selected_email_flags: index.zero? ? [] : ['email_conversation_assignment'],
                                                                       selected_push_flags: index.zero? ? ['push_conversation_assignment'] : []
                                                                     } }, as: :json
      expect(response).to have_http_status(:ok)
      preferences[business.id] = response.parsed_body
    end

    delete "/api/v1/accounts/#{account.id}/agents/#{member.id}", headers: admin_headers
    expect(response).to have_http_status(:ok)
    get "/api/v1/accounts/#{account.id}/notification_settings", headers: member_headers
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/accounts/#{account.id}/agents", headers: admin_headers,
                                                  params: { agent: { name: member.name, email: member.email, role: 'agent' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('id' => member.id, 'role' => 'agent')
    perform_enqueued_jobs(only: Agents::DestroyJob)

    [account, other_account].each do |business|
      get "/api/v1/accounts/#{business.id}/notification_settings", headers: member_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(preferences.fetch(business.id))
    end
  end
end
