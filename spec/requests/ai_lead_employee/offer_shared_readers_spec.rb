# frozen_string_literal: true

require 'rails_helper'

# Acceptance specification for the approved additive reader contract.
RSpec.describe 'Offer context in shared qualification readers', type: :request do
  include_context 'with Offer qualification requests'

  def prepare_two_qualified_offers
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Sales training'))
    first_conversation = r09_conversation(offer: first)
    second_conversation = r09_conversation(offer: second)
    r09_receive(first_conversation, 'My budget is TZS 600000.')
    r09_receive(second_conversation, 'My budget is TZS 987654.')
    [first, second, first_conversation, second_conversation]
  end

  it 'reads only the explicitly requested Offer with its structured evidence and provenance' do
    first, second, = prepare_two_qualified_offers

    [[first, 60_000_000], [second, 98_765_400]].each do |offer, amount|
      get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers,
                                                                               params: { offer_id: offer.fetch('id') }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('offer_id' => offer.fetch('id'), 'configuration_version' => offer.fetch('version'))
      expect(response.parsed_body.dig('evidence', 'budget')).to include('amount_minor' => amount, 'currency' => 'TZS')
      expect(response.parsed_body.fetch('evidence_records').map { |fact| fact.fetch('offer_id') }.uniq).to eq([offer.fetch('id')])
    end
  end

  it 'shows current staleness without changing the original observed amount or evaluated revision' do
    first, = prepare_two_qualified_offers
    r09_update_offer(first, name: 'Revised Offer')
    expect(response).to have_http_status(:success)

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers,
                                                                             params: { offer_id: first.fetch('id') }

    expect(response.parsed_body.fetch('stale_at')).to be_present
    expect(response.parsed_body.fetch('configuration_version')).to eq(first.fetch('version'))
    expect(response.parsed_body.dig('evidence', 'budget', 'amount_minor')).to eq(60_000_000)
  end

  it 'provides typed field labels and an authorized source link for the scoped evidence editor' do
    first, _second, conversation, = prepare_two_qualified_offers
    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers,
                                                                             params: { offer_id: first.fetch('id') }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('fields')).to include(include('key' => 'budget', 'answer_type' => 'money'))
    evidence = response.parsed_body.fetch('evidence_records').find { |record| record['field_key'] == 'budget' }
    source_path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}?messageId=#{evidence.dig('source_reference', 'message_id')}"
    expect(evidence.fetch('source_path')).to eq(source_path)
  end

  def source_projection_query_count(offer, conversation: nil)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] if payload[:sql].match?(/\ASELECT.*FROM "conversations"/m)
    end
    path = if conversation
             "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}"
           else
             "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}"
           end
    ActiveRecord::Base.uncached { get path, headers: r09_headers, params: { offer_id: offer.fetch('id') } }
    expect(response).to have_http_status(:success)
    queries.length
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it 'keeps authorized source-link query count bounded as evidence history spans more Conversations' do
    offer = r09_create_offer
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'My budget is TZS 600000.')
    single_reader_count = source_projection_query_count(offer)
    single_conversation_count = source_projection_query_count(offer, conversation: conversation)
    7.times do
      source = r09_conversation(offer: offer)
      create(:qualification_evidence, account: account, contact: r09_lead, offer_id: offer.fetch('id'), conversation: source)
    end

    expect(source_projection_query_count(offer)).to eq(single_reader_count)
    records = response.parsed_body.fetch('evidence_records')
    expect(records.length).to eq(8)
    expect(records.pluck('source_path').uniq.length).to eq(8)
    expect(source_projection_query_count(offer, conversation: conversation)).to eq(single_conversation_count)
    expect(response.parsed_body.dig('lead_qualification', 'evidence_records').length).to eq(8)
  end

  it 'uses the selected Offer when sorting and presenting a Lead with two qualifications' do
    first, = prepare_two_qualified_offers

    get "/api/v1/accounts/#{account.id}/leads", headers: r09_headers,
                                                params: { offer_id: first.fetch('id'), lead_id: r09_lead.id, sort: 'score', direction: 'desc' }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('selected_lead', 'detail', 'qualification')).to include('offer_id' => first.fetch('id'))
    expect(response.body).not_to include('987654')
  end

  it 'keeps the R06 combined-evidence restriction for a member who cannot access all Lead Conversations' do
    first, _second, assigned, = prepare_two_qualified_offers
    member = create(:user, account: account, role: :agent)
    assigned.update!(assignee: member)

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: member.create_new_auth_token,
                                                                             params: { offer_id: first.fetch('id') }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('quality')).to be_nil
    expect(response.parsed_body.fetch('evidence')).to be_empty
    expect(response.body).not_to include('987654')
  end

  it 'does not read an Offer from another account using an otherwise visible Lead' do
    first, = prepare_two_qualified_offers
    other_offer = create(:account).qualification_offers.create!(name: 'Foreign', currency: 'TZS')

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers,
                                                                             params: { offer_id: other_offer.id }

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(first.fetch('name'))
  end

  it 'returns a neutral selection state with Offers and separately labeled legacy history' do
    first, second, = prepare_two_qualified_offers
    create(:lead_qualification, account: account, contact: r09_lead, offer: nil, quality: :highly_qualified,
                                evidence_snapshot: { budget: { value: 'Historical budget 777777' } })

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('selection_required' => true, 'offer_id' => nil, 'quality' => nil, 'score' => nil,
                                            'evidence' => {}, 'evidence_records' => [], 'next_question' => nil)
    expect(response.parsed_body.fetch('offers').map { |offer| offer.fetch('id') }).to contain_exactly(first.fetch('id'), second.fetch('id'))
    expect(response.parsed_body.fetch('legacy_qualification')).to include('scope' => 'legacy_unscoped', 'quality' => 'highly_qualified')
  end

  it 'keeps unselected directory rows and counts neutral instead of applying qualification filters across Offers' do
    prepare_two_qualified_offers

    get "/api/v1/accounts/#{account.id}/leads", headers: r09_headers,
                                                params: { quality: 'unqualified', sort: 'score', lead_id: r09_lead.id }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('selection_required' => true, 'offer_id' => nil)
    expect(response.parsed_body.fetch('counts')).to include('all' => 1, 'unknown' => 1, 'low_qualified' => 0, 'unqualified' => 0)
    expect(response.parsed_body.fetch('selected_lead')).to include('quality' => 'unknown', 'score' => 0)
  end

  it 'applies quality filtering and counts to one explicit Offer rather than another Offer of the same Lead' do
    first, _second, conversation, = prepare_two_qualified_offers
    r09_update_offer(first, **higher_budget_requirement(first))
    expect(response).to have_http_status(:success)
    r09_receive(conversation, 'Hello')

    get "/api/v1/accounts/#{account.id}/leads", headers: r09_headers,
                                                params: { offer_id: first.fetch('id'), quality: 'unqualified', sort: 'score' }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('counts')).to include('all' => 1, 'unqualified' => 1, 'low_qualified' => 0)
    expect(response.parsed_body.fetch('leads').map { |lead| lead.fetch('id') }).to eq([r09_lead.id])
  end

  it 'projects only the Conversation selected Offer while retaining its control state and version' do
    first, _second, conversation, = prepare_two_qualified_offers
    state = conversation.reload.control_state
    version = conversation.control_version

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: r09_headers

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('control_state' => state, 'control_version' => version)
    expect(response.parsed_body.fetch('lead_qualification')).to include('offer_id' => first.fetch('id'))
    expect(response.parsed_body.dig('lead_qualification', 'evidence', 'budget')).to include('amount_minor' => 60_000_000)
  end

  it 'exposes staleness on a directory row as well as its detailed evaluated revision' do
    first, = prepare_two_qualified_offers
    r09_update_offer(first, name: 'Updated Offer')
    expect(response).to have_http_status(:success)

    get "/api/v1/accounts/#{account.id}/leads/#{r09_lead.id}", headers: r09_headers, params: { offer_id: first.fetch('id') }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('stale_at')).to be_present
    expect(response.parsed_body.fetch('configuration_version')).to eq(first.fetch('version'))
    expect(response.parsed_body.fetch('current_configuration_version')).to eq(first.fetch('version') + 1)
  end

  it 'reads a disabled Offer history without presenting an active next question' do
    first, = prepare_two_qualified_offers
    r09_update_offer(first, enabled: false)
    expect(response).to have_http_status(:success)

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers,
                                                                             params: { offer_id: first.fetch('id') }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('offer_id')).to eq(first.fetch('id'))
    expect(response.parsed_body.fetch('stale_at')).to be_present
    expect(response.parsed_body.fetch('next_question')).to be_nil
  end

  it 'exports qualification values from the explicit Offer through the existing CSV endpoint' do
    first, _second, conversation, = prepare_two_qualified_offers
    r09_update_offer(first, **higher_budget_requirement(first))
    expect(response).to have_http_status(:success)
    r09_receive(conversation, 'Hello')

    post "/api/v1/accounts/#{account.id}/leads/export", headers: r09_headers, params: { offer_id: first.fetch('id') }

    expect(response).to have_http_status(:success)
    rows = CSV.parse(response.body, headers: true)
    expect(rows.map { |row| row['quality'] }).to eq(['unqualified'])
  end

  def higher_budget_requirement(offer)
    {
      budget_ranges: [{ label: 'Higher minimum', minimum: '900000.00', enabled: true, position: 0 }],
      rules: offer.fetch('rules').map do |rule|
        rule['field'] == 'budget' ? rule.merge('value' => { 'amount' => '900000.00', 'currency' => 'TZS' }) : rule
      end
    }
  end
end
