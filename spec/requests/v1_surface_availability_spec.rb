require 'rails_helper'

RSpec.describe 'Standalone V1 surface availability', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'refuses unsupported channel creation even for an administrator' do
    post "/api/v1/accounts/#{account.id}/inboxes", headers: admin.create_new_auth_token,
                                                   params: { name: 'Unsupported inbox', channel: { type: 'api' } }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('WhatsApp')
    expect(account.inboxes.count).to eq(0)
  end

  it 'keeps a retained CE website widget unavailable on its direct public route' do
    inbox = create(:inbox, account: account)
    get '/widget', params: { website_token: inbox.channel.website_token }
    expect(response).to have_http_status(:not_found)
    %w[/hc /hc/example /survey/token /public/api/v1/inboxes/example/contacts /api/v1/widget/messages].each do |path|
      get path
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'keeps sign-in, password recovery and application health available' do
    get '/app/login'
    expect(response).to have_http_status(:ok)
    get '/app/auth/reset/password'
    expect(response).to have_http_status(:ok)
    get '/health'
    expect(response).to have_http_status(:ok)
  end

  it 'versions the owned login logo so browsers do not retain a cached Community Edition logo' do
    get '/app/login'
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{/brand-assets/logo\.svg\?v=[a-f0-9]+})
    expect(response.body).to match(%r{/brand-assets/logo_thumbnail\.svg\?v=[a-f0-9]+})
    expect(Rails.public_path.join('brand-assets/logo.svg').read).to include('<title>AI Lead Employee</title>')
  end
end
