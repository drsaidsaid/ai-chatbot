# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI subscription billing', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:platform_app) { create(:platform_app, finance_operations_enabled: true) }
  let(:platform_headers) { { api_access_token: platform_app.access_token.token } }
  let(:admin_headers) { admin.create_new_auth_token }

  before do
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
  end

  it 'publishes a draft tariff and activates one monthly entitlement from one verified payment', :aggregate_failures do
    post '/platform/api/v1/ai_service_plans', params: {
      code: 'growth', name: 'Growth', currency: 'TZS', monthly_price: '250000.00', included_ai_replies: 3000,
      top_up_price: '75000.00', top_up_ai_replies: 500,
      payment_instructions: 'Pay the approved invoice and share its reference.'
    }, headers: platform_headers, as: :json

    expect(response).to have_http_status(:created)
    plan_id = response.parsed_body.fetch('id')

    post "/platform/api/v1/ai_service_plans/#{plan_id}/publish", headers: platform_headers, as: :json
    expect(response).to have_http_status(:success)

    post "/api/v1/accounts/#{account.id}/ai_subscription/requests", params: {
      ai_service_plan_id: plan_id, purpose: 'new_subscription'
    }, headers: admin_headers, as: :json

    expect(response).to have_http_status(:created)
    request_id = response.parsed_body.fetch('id')
    expect(response.parsed_body).to include(
      'status' => 'pending',
      'amount' => '250000.0',
      'currency' => 'TZS',
      'payment_instructions' => 'Pay the approved invoice and share its reference.'
    )

    confirmation = {
      subscription_request_id: request_id,
      payment_reference: 'BANK-2026-0001',
      amount: '250000.00',
      currency: 'TZS',
      confirmed_at: '2026-09-12T08:00:00Z'
    }
    2.times do
      post "/platform/api/v1/accounts/#{account.id}/subscription_payment_confirmations",
           params: confirmation, headers: platform_headers, as: :json
      expect(response).to have_http_status(:success)
    end

    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account).count).to eq(1)
    get "/platform/api/v1/accounts/#{account.id}/billing_summary", headers: platform_headers, as: :json
    expect(response.parsed_body.fetch('customer_revenue_by_currency')).to eq('TZS' => '250000.0')

    get "/api/v1/accounts/#{account.id}/ai_subscription", headers: admin_headers, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('subscription')).to include(
      'plan_name' => 'Growth',
      'status' => 'active',
      'included_ai_replies' => 3000,
      'used_ai_replies' => 0,
      'remaining_ai_replies' => 3000,
      'usage_percentage' => 0.0
    )
    expect(response.parsed_body.fetch('separate_charges')).to include(
      'meta_messaging' => 'Billed directly by Meta',
      'advertising_spend' => 'Billed separately by the advertising platform'
    )
  end

  it 'does not allow published tariff terms to be rewritten' do
    plan = create(:ai_service_plan, status: :draft, published_at: nil, monthly_price: 250_000)
    post "/platform/api/v1/ai_service_plans/#{plan.id}/publish", headers: platform_headers, as: :json
    replacement = create(:ai_service_plan, status: :draft, published_at: nil, code: plan.code, version: 2,
                                           monthly_price: 300_000)
    post "/platform/api/v1/ai_service_plans/#{replacement.id}/publish", headers: platform_headers, as: :json

    patch(
      "/platform/api/v1/ai_service_plans/#{plan.id}",
      params: { monthly_price: '1.00' }, headers: platform_headers, as: :json
    )

    expect(response).to have_http_status(:unprocessable_entity)
    expect(plan.reload.monthly_price).to eq(250_000)
    expect(plan).to be_archived
  end

  it 'reports unknown provider cost as unknown rather than zero contribution cost', :aggregate_failures do
    connection = create(:ai_provider_connection, account: account)
    AiLeadEmployee::AiProviderUsage.create!(
      account: account, ai_provider_connection: connection, configuration_version: connection.configuration_version,
      purpose: 'answer', period_on: Date.new(2026, 9, 12), status: 'completed', requested_output_tokens: 512,
      cost_available: false, started_at: Time.zone.parse('2026-09-12T08:00:00Z'), completed_at: Time.current
    )

    get "/platform/api/v1/accounts/#{account.id}/billing_summary", headers: platform_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('provider_costs')).to include(
      'known_amount' => '0.0', 'unknown_records' => 1, 'complete' => false
    )
    expect(response.parsed_body.fetch('estimated_contribution_margin')).to include(
      'amount' => nil, 'complete' => false, 'reason' => 'provider_cost_unknown'
    )
    expect(response.parsed_body.fetch('meta_messaging')).to include('included_in_ai_credits' => false)
  end

  it 'does not let a Business Account admin confirm platform subscription payments' do
    post "/platform/api/v1/accounts/#{account.id}/subscription_payment_confirmations",
         params: { payment_reference: 'SELF-CONFIRMED' }, headers: admin_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.count).to eq(0)
  end

  it 'does not let a platform integration without finance authority manage tariffs' do
    provider_app = create(:platform_app, finance_operations_enabled: false)
    post '/platform/api/v1/ai_service_plans', params: {
      code: 'unauthorised', name: 'Unauthorised', currency: 'TZS', monthly_price: 100_000,
      included_ai_replies: 100, payment_instructions: 'Never accepted.'
    }, headers: { api_access_token: provider_app.access_token.token }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(AiLeadEmployee::AiServicePlan.where(code: 'unauthorised')).to be_empty
  end

  it 'rejects a catalogue whose approved top-up is cheaper per reply than a larger plan' do
    create(:ai_service_plan, code: 'growth', included_ai_replies: 1000, monthly_price: 100_000)
    plan = create(:ai_service_plan, status: :draft, published_at: nil, code: 'starter', included_ai_replies: 100,
                                    monthly_price: 20_000, top_up_price: 5_000, top_up_ai_replies: 100)

    post "/platform/api/v1/ai_service_plans/#{plan.id}/publish", headers: platform_headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(plan.reload).to be_draft
  end

  it 'does not let a Team Member request or inspect Business Account billing' do
    team_member = create(:user, account: account, role: :agent)

    get "/api/v1/accounts/#{account.id}/ai_subscription", headers: team_member.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
