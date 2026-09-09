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
end
