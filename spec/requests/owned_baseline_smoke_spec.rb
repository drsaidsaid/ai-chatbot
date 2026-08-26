# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

RSpec.describe 'Owned Community Edition baseline', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account, password: 'Password1!') }

  it 'boots the owned Rails endpoint' do
    get '/health'

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('status' => 'woot')
  end

  it 'keeps the pinned Community Edition baseline and MIT notice available' do
    expect(Rails.root.join('VERSION_CW').read.strip).to eq('4.17.0')
    expect(Rails.root.join('LICENSE').read).to include('MIT Expat')
    expect(Rails.root.join('LICENSE').read).to include('Permission is hereby granted, free of charge')
    expect(Rails.root.join('enterprise')).not_to exist
  end

  it 'uses owned branding and invite-only account access defaults' do
    installation_config = YAML.safe_load_file(Rails.root.join('config/installation_config.yml'))
    values = installation_config.index_by { |config| config['name'] }

    expect(values.dig('INSTALLATION_NAME', 'value')).to eq('AI Lead Employee')
    expect(values.dig('BRAND_NAME', 'value')).to eq('AI Lead Employee')
    expect(values.dig('ENABLE_ACCOUNT_SIGNUP', 'value')).to be(false)
    expect(values.dig('CREATE_NEW_ACCOUNT_FROM_DASHBOARD', 'value')).to be(false)
  end

  it 'keeps the owned local Rails, Vue, Redis, and worker stack wired together' do
    procfile = Rails.root.join('Procfile.dev').read
    cable_config = Rails.root.join('config/cable.yml').read
    sidekiq_initializer = Rails.root.join('config/initializers/sidekiq.rb').read
    development_environment = Rails.root.join('config/environments/development.rb').read

    expect(procfile).to include('backend: bin/rails s -p 3000')
    expect(procfile).to include('worker: dotenv bundle exec sidekiq -C config/sidekiq.yml')
    expect(procfile).to include('vite: bin/vite dev')
    expect(cable_config).to include('adapter: redis')
    expect(cable_config).to include("ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379')")
    expect(sidekiq_initializer).to include('config.redis = Redis::Config.app')
    expect(development_environment).to include('config.active_job.queue_adapter = :sidekiq')
  end

  it 'allows an initial admin to sign in, recover a password, and invite a team member' do
    post '/auth/sign_in',
         params: { email: admin.email, password: 'Password1!' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.headers['access-token']).to be_present

    post '/auth/password',
         params: { email: admin.email },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['message']).to be_present

    expect do
      post "/api/v1/accounts/#{account.id}/agents",
           headers: admin.create_new_auth_token,
           params: {
             agent: {
               email: 'operator@example.com',
               name: 'Human Operator',
               role: 'agent'
             }
           },
           as: :json
    end.to change(AccountUser, :count).by(1)

    expect(response).to have_http_status(:success)
    expect(AccountUser.joins(:user).exists?(account: account, users: { email: 'operator@example.com' })).to be(true)
  end

  it 'rejects account-scoped requests when the user is not a Business Account member' do
    other_account = create(:account)
    outsider = create(:user, :administrator, account: other_account)
    conversation = create(:conversation, account: account)

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
        headers: outsider.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'keeps background job conversation queries scoped to the Business Account' do
    agent = create(:user, account: account, role: :agent)
    conversation = create(:conversation, account: account, status: :open)
    other_account = create(:account)
    other_conversation = create(:conversation, account: other_account, status: :open)
    other_conversation.update!(display_id: conversation.display_id)
    create(:inbox_member, inbox: conversation.inbox, user: agent)

    BulkActionsJob.perform_now(
      account: account,
      params: { type: 'Conversation', fields: { status: 'resolved' }, ids: [conversation.display_id] },
      user: agent
    )

    expect(conversation.reload.status).to eq('resolved')
    expect(other_conversation.reload.status).to eq('open')
  end
end
