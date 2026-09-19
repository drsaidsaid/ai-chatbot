# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Business setup source review', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }

  let!(:offer) do
    account.qualification_offers.create!(
      name: 'Online Profits coaching', currency: 'TZS', enabled: true,
      configuration: { 'qualification_mode' => 'not_configured', 'next_step' => { 'kind' => 'answer_only' },
                       'questions' => [], 'budget_ranges' => [], 'rules' => [], 'score_weights' => {},
                       'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 } }
    )
  end

  let(:source_url) { "/api/v1/accounts/#{account.id}/qualification_offers/#{offer.id}/setup_sources" }

  def reviewed_configuration(record = offer, overrides = {})
    record.payload.slice(
      'name', 'currency', 'enabled', 'version', 'qualification_mode', 'next_step', 'questions', 'budget_ranges', 'rules',
      'score_weights', 'score_thresholds'
    ).deep_merge(overrides.deep_stringify_keys)
  end

  # This single tracer follows the public review -> explicit publication seam.
  # rubocop:disable RSpec/MultipleExpectations
  it 'keeps prose-derived facts and rules proposed until an administrator explicitly publishes the reviewed version' do
    original_version = offer.configuration_version

    post source_url, headers: headers, params: {
      source: {
        title: 'Coaching notes', source_type: 'pasted_prose',
        body: 'Online Profits coaching helps founders. A sales call requires a current business registration number. The price is TZS 50000.'
      }
    }, as: :json

    expect(response).to have_http_status(:created)
    proposal = response.parsed_body
    expect(proposal).to include('status' => 'proposed', 'offer_id' => offer.id, 'source_path' => "/business-setup-sources/#{proposal['id']}")
    expect(proposal.fetch('proposed_facts').join(' ')).to include('Online Profits coaching helps founders')
    expect(proposal.fetch('proposed_rules').join(' ')).to include('sales call requires a current business registration number')
    expect(proposal.dig('configuration', 'qualification_mode')).to eq('enabled')
    expect(proposal.dig('configuration', 'questions')).to include(
      include('answer_type' => 'boolean', 'purpose' => 'action_eligibility',
              'prompt' => 'Do you have a current business registration number?')
    )
    expect(proposal.dig('configuration', 'rules')).to include(
      include('kind' => 'requirement', 'dimension' => 'action_eligibility')
    )
    expect(proposal.fetch('unknowns').join(' ')).to include('current price')
    expect(offer.reload.configuration_version).to eq(original_version)

    post "#{source_url}/#{proposal['id']}/publish", headers: headers,
                                                    params: { expected_source_version: proposal.fetch('version'),
                                                              expected_offer_version: original_version }, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'published', 'published_offer_version' => original_version + 1)
    expect(offer.reload).to have_attributes(configuration_version: original_version + 1, qualification_mode: 'enabled')
    expect(offer.next_step).to include('kind' => 'sales_call')
    source = AiLeadEmployee::BusinessSetupSource.find(proposal.fetch('id'))
    expect(source.knowledge_document).to be_published
    expect(source.knowledge_document).to have_attributes(general_question_access: false, offer_ids: [offer.id])
    expect(source.knowledge_document.body).not_to include('TZS', '50000', 'price')
    expect(offer.commercial_proposals.pending.count).to eq(1)
    expect(offer.commercial_term).to be_nil
    safe_answer = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account, offer: offer, question: 'Tell me about Online Profits coaching'
    ).perform
    expect(safe_answer.answer).to include('Online Profits coaching helps founders')
    expect(safe_answer.answer).not_to include('TZS', '50000', 'price')
    expect(AiLeadEmployee::OfferPricingResolver.new(account: account, offer: offer).perform).to be_refused

    post "/api/v1/accounts/#{account.id}/evaluation_sandbox/runs", headers: headers,
                                                                   params: {
                                                                     scenario_key: 'business_setup_context',
                                                                     business_setup_source_id: source.id,
                                                                     question: 'Tell me about Online Profits coaching'
                                                                   }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('scenario_key' => 'business_setup_context')
    expect(response.parsed_body.dig('configuration_snapshot', 'business_setup_source', 'id')).to eq(source.id)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'fails closed on a stale Offer rather than applying an old reviewed proposal' do
    post source_url, headers: headers,
                     params: { source: { title: 'Service brief', body: 'A service for small teams.', source_type: 'document',
                                         reviewed_configuration: reviewed_configuration } }, as: :json
    proposal = response.parsed_body
    offer.update!(configuration_version: offer.configuration_version + 1)

    post "#{source_url}/#{proposal['id']}/publish", headers: headers,
                                                    params: { expected_source_version: proposal.fetch('version'),
                                                              expected_offer_version: offer.reload.configuration_version }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('error')).to match(/changed|stale/i)
    expect(AiLeadEmployee::BusinessSetupSource.find(proposal.fetch('id')).status).to eq('proposed')
  end

  it 'retains immutable reviewed snapshots and rejects a stale correction version' do
    post source_url, headers: headers,
                     params: { source: { title: 'First title', body: 'First complete fact.', source_type: 'document',
                                         reviewed_configuration: reviewed_configuration } }, as: :json
    proposal = response.parsed_body

    patch "#{source_url}/#{proposal['id']}", headers: headers,
                                             params: { expected_source_version: proposal.fetch('version'),
                                                       source: { title: 'Corrected title', body: 'Corrected complete fact.',
                                                                 source_type: 'document',
                                                                 reviewed_configuration: reviewed_configuration } }, as: :json

    expect(response).to have_http_status(:success)
    corrected = response.parsed_body
    expect(corrected.fetch('history').map { |revision| revision.slice('version', 'title', 'body') }).to eq(
      [
        { 'version' => 1, 'title' => 'First title', 'body' => 'First complete fact.' },
        { 'version' => 2, 'title' => 'Corrected title', 'body' => 'Corrected complete fact.' }
      ]
    )
    expect(corrected.fetch('history')).to all(include('proposal', 'digest', 'recorded_at'))

    patch "#{source_url}/#{proposal['id']}", headers: headers,
                                             params: { expected_source_version: 1,
                                                       source: { title: 'Lost edit', body: 'Lost edit.', source_type: 'document',
                                                                 reviewed_configuration: reviewed_configuration } }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(AiLeadEmployee::BusinessSetupSource.find(proposal['id']).title).to eq('Corrected title')
  end

  it 'archives the previous setup authority so normal inbound retrieval and Test Center use the correction' do
    first = create_and_publish_source('Growth coaching helps retailers with old guidance.')
    first_document = first.knowledge_document
    second = create_and_publish_source('Growth coaching helps retailers with corrected inventory guidance.')

    expect(first_document.reload).to be_archived
    expect(first).not_to be_current_published_offer
    expect(second).to be_current_published_offer
    inbound = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account, offer: offer, question: 'Tell me about Growth coaching inventory guidance'
    ).perform
    expect(inbound.answer).to include('corrected inventory guidance')
    expect(inbound.sources).to include(include(id: second.knowledge_document_id, type: 'knowledge_document'))
  end

  it 'reports a future published price as unavailable until its authoritative effective window starts' do
    terms = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: { amount: '50000', currency: 'TZS', quote_required: false,
                    effective_from: 2.days.from_now.iso8601, timezone: 'Africa/Dar_es_Salaam' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: terms.draft_version, editor: admin)

    post source_url, headers: headers,
                     params: { source: { title: 'Future price', source_type: 'document', body: 'We help retailers.',
                                         reviewed_configuration: reviewed_configuration(offer.reload) } }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch('unknowns').join(' ')).to include('current price')
  end

  {
    swahili_thousands: ['Tunatoa mafunzo kwa wafanyabiashara. Bei ni elfu hamsini.', '50000'],
    swahili_hundred_thousands: ['Tunatoa huduma ya uhasibu. Gharama ni laki mbili.', '200000'],
    bare_swahili_thousands: ['Tunasaidia biashara. Huduma yetu ni elfu hamsini.', '50000'],
    bare_swahili_hundred_thousands: ['Tunasaidia wajasiriamali. Mafunzo ni laki mbili.', '200000'],
    swahili_compound_thousands: ['Tunatoa mafunzo. Mafunzo ni elfu hamsini na tano.', '55000'],
    swahili_compound_laki: ['Tunatoa huduma. Huduma ni laki mbili na elfu hamsini.', '250000'],
    comma_grouped_currency: ['We help growing shops. The price is TZS 50,000.', '50000'],
    comma_grouped_dollars: ['We help global shops. Our service costs $1,250.00.', '1250.00', 'USD'],
    comma_grouped_shillings: ['We support retailers. Our service costs Sh250,000.', '250000'],
    mixed_revenue_clause: ['Growth coaching costs TZS50000 and helps increase revenue.', '50000'],
    revenue_named_offer: ['Revenue coaching costs TZS50000. It helps founders grow.', '50000'],
    actual_offer_identity_without_price_word: ['Online Profits coaching — TZS50,000. It helps founders grow.', '50000']
  }.each do |example_name, (body, amount, currency)|
    it "keeps #{example_name} pricing out of retrieved Knowledge and creates only an R20 proposal" do
      source = create_and_publish_source(body)
      document = source.knowledge_document
      proposal = source.offer.commercial_proposals.find_by!(knowledge_document: document)

      expect(document.body).not_to match(/TZS|USD|\$|\d|bei|gharama|elfu|laki|cost/i)
      expect(proposal.proposed_terms).to include('amount' => amount, 'currency' => currency || 'TZS')
      retrieved = AiLeadEmployee::KnowledgeAnswerService.new(
        account: account, offer: source.offer, question: source.title
      ).perform
      expect(retrieved.answer).not_to match(/TZS|USD|\$|\d|bei|gharama|elfu|laki|cost/i)
      expect(source.offer.commercial_term).to be_nil
    end
  end

  [
    'Huduma yetu ni elfu sabini na saba.',
    'Huduma yetu ni laki saba na elfu hamsini.',
    'Huduma yetu ni laki mbili na nusu.',
    'Huduma yetu ni elfu hamsini na mia tano.',
    'Huduma yetu ni laki mbili na elfu hamsini na mia tano.',
    'Huduma yetu ni milioni moja na laki mbili.',
    'Huduma yetu ni laki mbili na500.',
    'Huduma yetu ni elfu hamsini na5.',
    'Bei ni elfu hamsini au laki saba.'
  ].each do |unsupported_price|
    it "quarantines #{unsupported_price.inspect} instead of inventing a partial amount" do
      source = create_and_publish_source("Tunasaidia biashara. #{unsupported_price}")

      expect(source.knowledge_document.body).to eq('Tunasaidia biashara')
      expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
      expect(source.proposal.fetch('unknowns').join(' ')).to include('current price')
      expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
    end
  end

  {
    platform_charge: 'The platform subscription costs USD20.',
    lead_budget: 'The lead budget is TZS50000.'
  }.each do |context, excluded_claim|
    it "keeps the #{context} separate from authoritative Offer pricing" do
      source = create_and_publish_source("We help growing businesses. #{excluded_claim}")

      expect(source.knowledge_document.body).to include(excluded_claim.delete_suffix('.'))
      expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
      expect(source.offer.commercial_term).to be_nil
    end
  end

  it 'quarantines an ambiguous mixed financial and Offer-price subject' do
    source = create_and_publish_source('We help growing businesses. Revenue and coaching cost TZS50000.')

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    expect(source.proposal.fetch('unknowns').join(' ')).to include('current price')
    expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
  end

  it 'quarantines a mixed Offer price and platform-subscription subject' do
    source = create_and_publish_source('We help growing businesses. Coaching costs TZS50000 including platform subscription.')

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
  end

  it 'quarantines an unknown financial-sounding product name without explicit price language' do
    source = create_and_publish_source('We help growing businesses. Revenue Accelerator — TZS50000.')

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
  end

  it 'keeps an explicit revenue metric non-Offer even when the sentence names the Offer' do
    source = create_and_publish_source('Online Profits coaching helps clients reach revenue of TZS50000.')

    expect(source.knowledge_document.body).to include('revenue of TZS50000')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
  end

  it 'quarantines a mixed explicit Offer price and financial metric from proposals and retrieved Knowledge' do
    source = create_and_publish_source(
      'We help growing businesses. Coaching costs USD100 for businesses whose revenue is USD1000.'
    )

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
    retrieved = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account, offer: source.offer, question: 'What does the coaching cost for businesses by revenue?'
    ).perform
    expect(retrieved.answer).not_to match(/USD|100|1000/)
  end

  it 'quarantines a financial metric followed by an explicit Offer price from proposals and retrieved Knowledge' do
    source = create_and_publish_source(
      'We help growing businesses. Businesses whose revenue is USD1000 pay a coaching price of USD100.'
    )

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
    retrieved = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account, offer: source.offer, question: 'What do businesses pay by revenue?'
    ).perform
    expect(retrieved.answer).not_to match(/USD|100|1000/)
  end

  [
    ['Online Profits', 'Online Profits — USD100 for businesses whose revenue is USD1000.'],
    ['Online Profits coaching', 'Online Profits coaching — USD100 for businesses whose revenue is USD1000.']
  ].each do |offer_name, mixed_claim|
    it "quarantines distinct Offer identity and metric amounts without price words for #{offer_name.inspect}" do
      offer.update!(name: offer_name)
      source = create_and_publish_source("We help growing businesses. #{mixed_claim}")

      expect(source.knowledge_document.body).to eq('We help growing businesses')
      expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
      expect(source.proposal.fetch('unknowns').join(' ')).to include('could not be safely assigned')
      retrieved = AiLeadEmployee::KnowledgeAnswerService.new(
        account: account, offer: source.offer, question: 'What does the offer cost for businesses by revenue?'
      ).perform
      expect(retrieved.answer).not_to match(/USD|100|1000/)
    end
  end

  it 'matches Offer identity at token boundaries rather than inside unrelated words' do
    offer.update!(name: 'Pro')
    source = create_and_publish_source('Revenue is TZS50000 from products.')

    expect(source.knowledge_document.body).to include('Revenue is TZS50000 from products')
    expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
  end

  {
    'Revenue' => 'Revenue is our coaching package for TZS50000.',
    'Income of Africa' => 'Income of Africa — TZS50000.'
  }.each do |offer_name, price_claim|
    it "treats an overlapping financial phrase as the exact Offer identity for #{offer_name.inspect}" do
      offer.update!(name: offer_name)
      source = create_and_publish_source("We help growing businesses. #{price_claim}")
      proposal = source.offer.commercial_proposals.find_by!(knowledge_document: source.knowledge_document)

      expect(source.knowledge_document.body).to eq('We help growing businesses')
      expect(proposal.proposed_terms).to include('amount' => '50000', 'currency' => 'TZS')
    end
  end

  {
    'Revenue' => 'Client revenue is TZS50000.',
    'Income' => 'Client income is TZS50000.',
    'Salary' => 'Client salary is TZS50000.'
  }.each do |offer_name, metric_claim|
    it "keeps a generic one-token Offer name #{offer_name.inspect} from capturing a client metric" do
      offer.update!(name: offer_name)
      source = create_and_publish_source("We help growing businesses. #{metric_claim}")

      expect(source.knowledge_document.body).to include(metric_claim.delete_suffix('.'))
      expect(source.offer.commercial_proposals.where(knowledge_document: source.knowledge_document)).to be_empty
    end
  end

  it 'keeps every amount under a shared price predicate for conflict review' do
    source = create_and_publish_source('We help growing businesses. The price is TZS50000 and TZS60000.')
    proposal = source.offer.commercial_proposals.find_by!(knowledge_document: source.knowledge_document)

    expect(source.knowledge_document.body).to eq('We help growing businesses')
    expect(proposal).to be_conflict_review
    expect(proposal.proposed_terms.fetch('candidates').pluck('amount')).to contain_exactly('50000', '60000')
  end

  it 'keeps a Swahili quote policy out of Knowledge and proposes quote-required pricing for R20 review' do
    source = create_and_publish_source('Tunatoa ushauri kwa biashara. Wasiliana nasi kwa nukuu ya bei.')
    proposal = source.offer.commercial_proposals.find_by!(knowledge_document: source.knowledge_document)

    expect(source.knowledge_document.body).to eq('Tunatoa ushauri kwa biashara')
    expect(proposal.proposed_terms).to include('quote_required' => true, 'proposal_kind' => 'quote_required')
    expect(source.offer.commercial_term).to be_nil
  end

  it 'handles supported next-step negation and need language without proposing the opposite behavior' do
    post source_url, headers: headers,
                     params: { source: { title: 'No call', source_type: 'document',
                                         body: 'We answer customer questions. No sales call required.' } }, as: :json
    no_call = response.parsed_body
    expect(no_call.dig('configuration', 'next_step', 'kind')).to eq('answer_only')
    expect(no_call.dig('configuration', 'qualification_mode')).to eq('not_configured')
    expect(no_call.dig('configuration', 'questions')).to be_empty

    post source_url, headers: headers,
                     params: { source: { title: 'Bookkeeping', source_type: 'document',
                                         body: 'We provide bookkeeping. Enquiries need a current business registration number.' } }, as: :json
    bookkeeping = response.parsed_body
    expect(bookkeeping.dig('configuration', 'next_step', 'kind')).to eq('enquiry')
    expect(bookkeeping.dig('configuration', 'qualification_mode')).to eq('enabled')
    expect(bookkeeping.dig('configuration', 'rules')).to include(include('kind' => 'requirement'))
  end

  it 'leaves vague fit confirmation as an owner clarification instead of asking a circular Lead question' do
    post source_url, headers: headers,
                     params: { source: { title: 'Vague sales rule', source_type: 'document',
                                         body: 'We coach founders. A sales call requires confirmed fit.' } }, as: :json

    proposal = response.parsed_body
    expect(proposal.dig('configuration', 'next_step', 'kind')).to eq('sales_call')
    expect(proposal.dig('configuration', 'qualification_mode')).to eq('not_configured')
    expect(proposal.dig('configuration', 'questions')).to be_empty
    expect(proposal.dig('configuration', 'rules')).to be_empty
    expect(proposal.fetch('proposed_rules')).to be_empty
    expect(proposal.fetch('unknowns').join(' ')).to include('lead-addressable qualification requirement')
  end

  it 'treats explicit Swahili no-qualification wording as disabled rather than an ordinary fact' do
    post source_url, headers: headers,
                     params: { source: { title: 'Duka la bidhaa', source_type: 'document',
                                         body: 'Tunauza bidhaa za nyumbani. Bei ipo kwenye kiungo cha ununuzi. ' \
                                               'Hakuna maswali ya ustahiki.' } }, as: :json

    proposal = response.parsed_body
    expect(proposal.dig('configuration', 'qualification_mode')).to eq('disabled')
    expect(proposal.dig('configuration', 'questions')).to be_empty
    expect(proposal.dig('configuration', 'rules')).to be_empty
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'keeps explanatory fit negations out of requirements and asks owners to clarify alternative qualifications' do
    post source_url, headers: headers, params: {
      source: {
        title: 'Owner-approved pilot notes', source_type: 'pasted_prose', body: <<~NOTES
          Online Profits University offers 12 months of mentoring to help people build an expert-based business using their expertise to solve problems online through products or services.
          A suitable lead has no business yet, or monthly business revenue below TZS 1,000,000. They are willing to build an expert-based business and invest in mentoring. Business revenue is different from salary, profit and available budget.
          Ask naturally about missing business facts, their goal, their obstacle and readiness to speak. Do not repeat information already supplied. Fit does not automatically mean willingness to speak or buy. A sales call requires their agreement. The team will arrange calls manually during this pilot.
          The current programme price needs a team quote. Do not quote historical promotions or future prices. Growth goals are aspirations, not guaranteed results.
          Answer genuine programme questions in English or Swahili using approved information. Do not provide a free personalized business consulting session. Acknowledge strategic questions and ask one useful qualifying question. Do not invent resource links.
          For a relevant unanswered business question, acknowledge the gap and create a human review request without promising a callback deadline. Respect stop requests and human takeover. Unrelated questions receive a polite scope boundary.
          Data deletion requests: support@onlineprofits.co.tz.
        NOTES
      }
    }, as: :json

    proposal = response.parsed_body
    questions = proposal.dig('configuration', 'questions')
    rules = proposal.dig('configuration', 'rules')

    expect(questions).to include(
      include('key' => 'sales_call_agreement', 'answer_type' => 'boolean',
              'prompt' => 'Would you like a sales call?', 'purpose' => 'action_eligibility')
    )
    expect(rules).to include(
      include('field' => 'sales_call_agreement', 'operator' => 'eq', 'value' => true,
              'dimension' => 'action_eligibility')
    )
    expect(questions.pluck('meaning').join(' ')).not_to include('Fit does not automatically mean willingness')
    expect(proposal.fetch('proposed_rules').join(' ')).not_to include('Fit does not automatically mean willingness')
    expect(proposal.fetch('unknowns').join(' ')).to include('qualification alternatives')
    expect(proposal.fetch('unknowns').join(' ')).not_to include('monetary statement could not')

    post "#{source_url}/#{proposal.fetch('id')}/publish", headers: headers,
                                                          params: { expected_source_version: proposal.fetch('version'),
                                                                    expected_offer_version: offer.reload.configuration_version }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('error')).to include('Clarify the qualification alternatives')
    expect(offer.reload).to have_attributes(qualification_mode: 'not_configured')
    expect(offer.next_step).to include('kind' => 'answer_only')
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'allows answer-only knowledge publication when only a current price is unknown' do
    post source_url, headers: headers,
                     params: { source: { title: 'Quote-only knowledge', source_type: 'document',
                                         body: 'We help founders build practical online businesses. ' \
                                               'The current programme price needs a team quote.' } }, as: :json
    proposal = response.parsed_body

    expect(proposal.fetch('unknowns').join(' ')).to include('current price')

    post "#{source_url}/#{proposal.fetch('id')}/publish", headers: headers,
                                                          params: { expected_source_version: proposal.fetch('version'),
                                                                    expected_offer_version: offer.reload.configuration_version }, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'deduplicates repeated sales-call agreement sentences within one proposal' do
    post source_url, headers: headers,
                     params: { source: { title: 'Repeated agreement', source_type: 'document',
                                         body: 'We coach founders. A sales call requires their agreement. ' \
                                               'A sales call requires their agreement.' } }, as: :json

    proposal = response.parsed_body
    expect(proposal.dig('configuration', 'questions').pluck('key')).to eq(['sales_call_agreement'])
    expect(proposal.dig('configuration', 'rules').pluck('field')).to eq(['sales_call_agreement'])
  end

  it 'computes missing links and ambiguous actions after prose inference' do
    post source_url, headers: headers,
                     params: { source: { title: 'Purchase', source_type: 'document',
                                         body: 'We sell home products. Buy now through our purchase link.' } }, as: :json
    expect(response.parsed_body.dig('configuration', 'next_step', 'kind')).to eq('purchase_link')
    expect(response.parsed_body.fetch('unknowns').join(' ')).to include('approved link')

    post source_url, headers: headers,
                     params: { source: { title: 'Ambiguous', source_type: 'document',
                                         body: 'We help retailers. Book an appointment or request a sales call.' } }, as: :json
    expect(response.parsed_body.dig('configuration', 'next_step', 'kind')).to eq('answer_only')
    expect(response.parsed_body.fetch('unknowns').join(' ')).to include('multiple possible next steps')
  end

  it 'replaces obsolete source-owned requirements on correction while preserving independent edits' do
    post source_url, headers: headers,
                     params: { source: { title: 'Fit draft', source_type: 'document',
                                         body: 'Customers need a retail registration.' } }, as: :json
    first = response.parsed_body
    old_key = first.dig('configuration', 'questions', 0, 'key')
    reviewed = first.fetch('configuration').deep_dup
    reviewed['questions'] << {
      'key' => 'independent_readiness', 'meaning' => 'Independent readiness', 'answer_type' => 'boolean',
      'prompt' => 'Are you ready?', 'position' => 1, 'enabled' => true, 'required' => true, 'purpose' => 'readiness'
    }
    reviewed['rules'] << {
      'kind' => 'requirement', 'dimension' => 'readiness', 'field' => 'independent_readiness',
      'operator' => 'positive', 'value' => nil, 'priority' => 1, 'enabled' => true
    }

    patch "#{source_url}/#{first.fetch('id')}", headers: headers,
                                                params: { expected_source_version: first.fetch('version'),
                                                          source: { title: 'Fit draft', source_type: 'document',
                                                                    body: 'Customers need an active tax registration.',
                                                                    reviewed_configuration: reviewed } }, as: :json

    corrected = response.parsed_body
    keys = corrected.dig('configuration', 'questions').pluck('key')
    expect(keys).not_to include(old_key)
    expect(keys).to include('independent_readiness')
    expect(keys.grep(/setup_fit_/).size).to eq(1)
    expect(corrected.dig('configuration', 'rules')).to include(include('field' => 'independent_readiness'))
  end

  it 'replaces published source-owned requirements while preserving independent Offer edits' do
    first = create_and_publish_source('Retail customers need an active retail registration.')
    retail_key = first.proposal.fetch('generated_question_keys').sole
    independently_edited = reviewed_configuration(offer.reload)
    independently_edited['questions'] << {
      'key' => 'independent_readiness', 'meaning' => 'Independent readiness', 'answer_type' => 'boolean',
      'prompt' => 'Are you ready?', 'position' => 1, 'enabled' => true, 'required' => true, 'purpose' => 'readiness'
    }
    independently_edited['rules'] << {
      'kind' => 'requirement', 'dimension' => 'readiness', 'field' => 'independent_readiness',
      'operator' => 'positive', 'value' => nil, 'priority' => 1, 'enabled' => true
    }
    AiLeadEmployee::OfferConfigurationWriter.new(offer: offer.reload, attributes: independently_edited).perform

    replacement = create_and_publish_source('Restaurant customers need an active food-service registration.')
    keys = offer.reload.configuration.fetch('questions').pluck('key')

    expect(keys).not_to include(retail_key)
    expect(keys).to include('independent_readiness')
    expect(keys.grep(/setup_fit_/)).to contain_exactly(replacement.proposal.fetch('generated_question_keys').sole)
    expect(offer.configuration.fetch('rules')).to include(include('field' => 'independent_readiness'))
    expect(first.knowledge_document.reload).to be_archived
  end

  it 'clears published source-owned sales-call and qualification behavior when its replacement removes them' do
    first = create_and_publish_source('We coach founders. A sales call requires a current business registration number.')
    expect(offer.reload.next_step).to include('kind' => 'sales_call')
    expect(offer).to be_qualification_enabled

    replacement = create_and_publish_source('We answer founder questions. No qualification required.')

    expect(offer.reload.next_step).to include('kind' => 'answer_only')
    expect(offer.qualification_mode).to eq('disabled')
    expect(offer.configuration.values_at('questions', 'rules')).to eq([[], []])
    expect(replacement.proposal.dig('source_ownership', 'qualification_mode', 'value')).to eq('disabled')
    expect(first.knowledge_document.reload).to be_archived
  end

  it 'does not reset an independently edited next step or qualification mode during source replacement' do
    create_and_publish_source('We coach founders. A sales call requires a current business registration number.')
    independent = reviewed_configuration(
      offer.reload,
      qualification_mode: 'disabled',
      next_step: { kind: 'appointment', url: 'https://example.test/book' }
    )
    AiLeadEmployee::OfferConfigurationWriter.new(offer: offer, attributes: independent).perform

    create_and_publish_source('We answer founder questions.')

    expect(offer.reload.next_step).to include('kind' => 'appointment', 'url' => 'https://example.test/book')
    expect(offer.qualification_mode).to eq('disabled')
  end

  it 'does not expose another Business Account’s source history' do
    source = AiLeadEmployee::BusinessSetupSource.create!(account: account, offer: offer, title: 'Private', source_type: 'pasted_prose',
                                                         body: 'Private source', proposal: {}, status: :proposed, version: 1)
    other = create(:account)
    other_admin = create(:user, account: other, role: :administrator)

    get "/api/v1/accounts/#{other.id}/qualification_offers/#{offer.id}/setup_sources/#{source.id}", headers: other_admin.create_new_auth_token,
                                                                                                    as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'admits only a published, account-owned setup source to the no-send Test Center path' do
    unpublished = AiLeadEmployee::BusinessSetupSource.create!(
      account: account, offer: offer, title: 'Draft source', source_type: 'pasted_prose', body: 'Draft', proposal: {}, status: :proposed
    )

    post "/api/v1/accounts/#{account.id}/evaluation_sandbox/runs",
         headers: headers,
         params: { scenario_key: 'unknown_question', business_setup_source_id: unpublished.id },
         as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects a published source after its Offer revision changes' do
    source = AiLeadEmployee::BusinessSetupSource.create!(
      account: account, offer: offer, title: 'Published source', source_type: 'document', body: 'Published', proposal: {},
      status: :published, version: 1, published_offer_version: offer.configuration_version, published_at: Time.current, published_by: admin
    )
    offer.update!(configuration_version: offer.configuration_version + 1)

    post "/api/v1/accounts/#{account.id}/evaluation_sandbox/runs",
         headers: headers,
         params: { scenario_key: 'unknown_question', business_setup_source_id: source.id },
         as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects another Business Account’s otherwise published source from Test Center' do
    other = create(:account)
    foreign_offer = other.qualification_offers.create!(name: 'Foreign Offer', currency: 'TZS')
    foreign_source = AiLeadEmployee::BusinessSetupSource.create!(
      account: other, offer: foreign_offer, title: 'Foreign source', source_type: 'document', body: 'Foreign', proposal: {},
      status: :published, version: 1, published_offer_version: foreign_offer.configuration_version, published_at: Time.current
    )

    post "/api/v1/accounts/#{account.id}/evaluation_sandbox/runs",
         headers: headers,
         params: { scenario_key: 'unknown_question', business_setup_source_id: foreign_source.id },
         as: :json

    expect(response).to have_http_status(:not_found)
  end

  BusinessSetupFixtureMatrix::FIXTURES.each do |key, fixture|
    it "previews the #{key} setup in #{fixture[:language]} without activating it" do
      configured_offer = if key == :online_profits_en
                           offer.tap do |record|
                             record.update!(configuration: record.configuration.merge(
                               'qualification_mode' => fixture[:qualification_mode],
                               'next_step' => { 'kind' => fixture[:next_step] }
                             ))
                           end
                         else
                           account.qualification_offers.create!(
                             name: fixture[:business], currency: 'TZS',
                             configuration: offer.configuration.merge(
                               'qualification_mode' => fixture[:qualification_mode],
                               'next_step' => { 'kind' => fixture[:next_step] }
                             )
                           )
                         end

      if fixture[:commercial_terms]
        terms = AiLeadEmployee::CommercialTerms.save_draft!(offer: configured_offer, attributes: fixture[:commercial_terms])
        AiLeadEmployee::CommercialTerms.publish!(offer: configured_offer, expected_version: terms.draft_version, editor: admin)
        configured_offer.reload
      end
      preview_version = configured_offer.configuration_version

      next_step = { kind: fixture[:next_step] }
      next_step[:url] = fixture[:next_step_url] if fixture[:next_step_url]

      post "/api/v1/accounts/#{account.id}/qualification_offers/#{configured_offer.id}/setup_sources",
           headers: headers,
           params: { source: { title: key.to_s, source_type: 'document', body: fixture[:source],
                               reviewed_configuration: reviewed_configuration(
                                 configured_offer,
                                 qualification_mode: fixture[:qualification_mode], next_step: next_step
                               ) } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('status' => 'proposed')
      expect(response.parsed_body.fetch('configuration')).to include(
        'qualification_mode' => fixture[:qualification_mode], 'next_step' => include('kind' => fixture[:next_step])
      )
      unknowns = response.parsed_body.fetch('unknowns').join(' ')
      if fixture[:expected_unknown]
        expect(unknowns).to include(fixture[:expected_unknown])
      else
        expect(unknowns).to be_empty
      end
      expect(configured_offer.reload.configuration_version).to eq(preview_version)
    end
  end

  def create_and_publish_source(body)
    post source_url, headers: headers,
                     params: { source: { title: 'Growth setup', source_type: 'document', body: body,
                                         reviewed_configuration: reviewed_configuration(offer.reload) } }, as: :json
    proposal = response.parsed_body
    post "#{source_url}/#{proposal.fetch('id')}/publish", headers: headers,
                                                          params: { expected_source_version: proposal.fetch('version'),
                                                                    expected_offer_version: offer.reload.configuration_version }, as: :json
    expect(response).to have_http_status(:success)
    AiLeadEmployee::BusinessSetupSource.find(proposal.fetch('id'))
  end
end
