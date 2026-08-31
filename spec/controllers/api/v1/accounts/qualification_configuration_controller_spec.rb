# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Qualification Configuration API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'shows the complete default question list for a new account' do
    get "/api/v1/accounts/#{account.id}/qualification_configuration",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['questions'].first).to include(
      'id' => nil,
      'signal' => 'name',
      'prompt' => 'What is your name?',
      'position' => 0,
      'enabled' => true
    )
    expect(response.parsed_body['questions'].pluck('signal')).to include('business_type', 'budget', 'contact_details')
  end

  it 'lets an admin configure questions and budget ranges with a version bump' do
    question = create(:qualification_question, account: account, signal: :problem)

    patch "/api/v1/accounts/#{account.id}/qualification_configuration",
          headers: admin.create_new_auth_token,
          params: {
            questions: [
              { id: question.id, signal: 'problem', prompt: 'What is the main blocker?', position: 2, enabled: false },
              { signal: 'budget', prompt: 'What budget range works?', position: 1, enabled: true }
            ],
            budget_ranges: [
              { label: '$500 - $1,500', min_cents: 50_000, max_cents: 150_000, position: 1, enabled: true }
            ],
            follow_up: {
              enabled: true,
              delay_minutes: 120,
              max_attempts: 2,
              qualified_second_follow_up_enabled: true,
              stage_rules: {
                budget: { enabled: false }
              }
            }
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['version']).to eq(2)
    expect(response.parsed_body['questions'].pluck('prompt')).to eq(
      ['What is your name?', 'What budget range works?', 'What is the main blocker?']
    )
    expect(question.reload.enabled).to be(false)
    expect(account.qualification_budget_ranges.first.label).to eq('$500 - $1,500')
    expect(response.parsed_body.dig('follow_up', 'delay_minutes')).to eq(120)
    expect(response.parsed_body.dig('follow_up', 'stage_rules', 'budget', 'enabled')).to be(false)
  end

  it 'prevents a Human Operator without admin access from changing configuration' do
    patch "/api/v1/accounts/#{account.id}/qualification_configuration",
          headers: agent.create_new_auth_token,
          params: { questions: [{ signal: 'budget', prompt: 'Budget?', position: 1, enabled: true }] },
          as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(account.qualification_questions).to be_empty
  end
end
