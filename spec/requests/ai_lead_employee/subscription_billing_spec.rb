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

  it 'scopes provider costs to the exact UTC timestamps of an account-local subscription period' do
    travel_to Time.zone.parse('2026-09-20T12:00:00Z') do
      plan = create(:ai_service_plan)
      create(:ai_subscription, account: account, ai_service_plan: plan, reporting_timezone: 'Africa/Dar_es_Salaam',
                               period_started_at: Time.zone.parse('2026-09-11T21:00:00Z'),
                               renews_at: Time.zone.parse('2026-10-11T21:00:00Z'),
                               paid_through_at: Time.zone.parse('2026-10-11T21:00:00Z'))
      connection = create(:ai_provider_connection, account: account)
      [
        ['2026-09-11T20:59:59Z', 100], ['2026-09-11T21:00:00Z', 2],
        ['2026-10-11T20:59:59.999999Z', 3], ['2026-10-11T21:00:00Z', 200]
      ].each do |started_at, cost|
        instant = Time.zone.parse(started_at)
        AiLeadEmployee::AiProviderUsage.create!(
          account: account, ai_provider_connection: connection,
          configuration_version: connection.configuration_version, purpose: 'answer', period_on: instant.to_date,
          status: 'completed', requested_output_tokens: 512, cost_available: true, cost_usd: cost,
          started_at: instant, completed_at: instant
        )
      end

      get "/platform/api/v1/accounts/#{account.id}/billing_summary", headers: platform_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.fetch('provider_costs')).to include('known_amount' => '5.0', 'complete' => true)
    end
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

  it 'lists conservative reconciliation work and refuses manual settlement without canonical acceptance' do
    create(:ai_subscription, account: account, included_ai_replies: 2)
    intent = create(:ai_orchestration_intent, account: account)
    usage = AiLeadEmployee::ReplyAllowance.reserve!(intent: intent)
    message = create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                               message_type: :outgoing,
                               additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    delivery = Whatsapp::OutboundDelivery.create!(
      account: account, conversation: message.conversation, message: message, ai_reply_usage: usage,
      observed_control_version: message.conversation.control_version
    )
    AiLeadEmployee::ReplyAllowance.register_deliveries!(usage: usage, messages: [message])
    delivery.update!(state: :unknown, failure_code: 'acceptance_unknown')

    get "/platform/api/v1/accounts/#{account.id}/ai_reply_usages", headers: platform_headers, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('items').sole).to include(
      'id' => usage.id, 'status' => 'reserved', 'reconciliation_reason' => 'acceptance_unknown'
    )

    get "/platform/api/v1/accounts/#{account.id}/ai_reply_usages", params: { status: 'invented' },
                                                                   headers: platform_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    patch "/platform/api/v1/accounts/#{account.id}/ai_reply_usages/#{usage.id}",
          params: { outcome: 'confirmed_sent', reason: 'operator_lookup' }, headers: platform_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(usage.reload).to be_reserved
  end

  it 'tracks operating cost allocations and calculates complete USD contribution margin' do
    plan = create(:ai_service_plan, currency: 'USD', monthly_price: 100)
    request = AiLeadEmployee::Subscriptions::RequestService.new(
      account: account, requested_by: admin, plan: plan, purpose: :new_subscription
    ).perform
    AiLeadEmployee::Subscriptions::PaymentConfirmationService.new(
      account: account, request: request, platform_app: platform_app,
      attributes: { payment_reference: 'USD-REVENUE', amount: 100, currency: 'USD', confirmed_at: Time.current.iso8601 }
    ).perform

    subscription = AiLeadEmployee::AiSubscription.find_by!(account: account)
    zone = ActiveSupport::TimeZone[subscription.reporting_timezone]
    period_start = subscription.period_started_at.in_time_zone(zone).to_date
    period_end = (subscription.renews_at.in_time_zone(zone) - 1.second).to_date

    post "/platform/api/v1/accounts/#{account.id}/cost_allocations", params: {
      category: :hosting, amount: 1, currency: 'USD', period_started_on: period_start, period_ended_on: period_start
    }, headers: platform_headers, as: :json
    expect(response).to have_http_status(:created)

    get "/platform/api/v1/accounts/#{account.id}/billing_summary", headers: platform_headers, as: :json
    expect(response.parsed_body.fetch('operating_cost_allocations')).to include('complete' => false)
    expect(response.parsed_body.fetch('estimated_contribution_margin')).to include(
      'amount' => nil, 'complete' => false, 'reason' => 'operating_costs_unallocated'
    )
    AiLeadEmployee::AccountCostAllocation.where(account: account).delete_all

    { hosting: 10, payment_processing: 3, support: 7 }.each do |category, amount|
      post "/platform/api/v1/accounts/#{account.id}/cost_allocations", params: {
        category: category, amount: amount, currency: 'USD',
        period_started_on: period_start, period_ended_on: period_end
      }, headers: platform_headers, as: :json
      expect(response).to have_http_status(:created)
    end

    get "/platform/api/v1/accounts/#{account.id}/billing_summary", headers: platform_headers, as: :json

    expect(response.parsed_body.fetch('operating_cost_allocations')).to include(
      'totals_by_currency' => { 'USD' => '20.0' }, 'complete' => true
    )
    expect(response.parsed_body.fetch('estimated_contribution_margin')).to include(
      'amount' => '80.0', 'currency' => 'USD', 'complete' => true
    )
  end

  it 'translates a database-level overlapping cost allocation conflict' do
    attributes = {
      account: account, recorded_by_platform_app: platform_app, category: 'hosting', amount: 1, currency: 'USD',
      period_started_on: Date.new(2026, 9, 1), period_ended_on: Date.new(2026, 9, 30)
    }
    AiLeadEmployee::AccountCostAllocation.create!(attributes)
    force_overlap = lambda do |allocation|
      allocation.period_started_on = Date.new(2026, 9, 15)
    end
    AiLeadEmployee::AccountCostAllocation.set_callback(:create, :before, force_overlap)

    begin
      post "/platform/api/v1/accounts/#{account.id}/cost_allocations", params: {
        category: :hosting, amount: 2, currency: 'USD',
        period_started_on: '2026-10-01', period_ended_on: '2026-10-15'
      }, headers: platform_headers, as: :json
    ensure
      AiLeadEmployee::AccountCostAllocation.skip_callback(:create, :before, force_overlap)
    end

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch('error')).to eq('Cost allocation periods must not overlap')
  end
end
