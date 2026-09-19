# frozen_string_literal: true

require 'digest'
require 'json'

def canonical_json(value)
  deep_sort = lambda do |entry|
    case entry
    when Hash
      entry.keys.sort.index_with { |key| deep_sort.call(entry.fetch(key)) }
    when Array
      entry.map { |item| deep_sort.call(item) }
    else
      entry
    end
  end
  JSON.generate(deep_sort.call(value))
end

database = ActiveRecord::Base.connection_db_config.database
allowed_database = ENV.fetch('R12_BROWSER_DATABASE', nil)
valid_browser_database = Rails.env.test? && database == allowed_database && database&.match?(/\Aale_r12_[a-z0-9_]+_browser\z/)
abort 'Use RAILS_ENV=test and an explicitly named ale_r12_*_browser database.' unless valid_browser_database
abort 'Use a fresh browser database; existing accounts and users are never replaced.' if Account.exists? || User.exists?

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test

ConfigLoader.new.process
password = ENV.fetch('R12_BROWSER_PASSWORD')
account = Account.create!(name: 'R12 Synthetic Review Business', locale: 'en')
admin = User.new(name: 'R12 Admin', email: 'r12-admin@example.test', password: password)
admin.skip_confirmation!
admin.save!
operator = User.new(name: 'R12 Operator', email: 'r12-operator@example.test', password: password)
operator.skip_confirmation!
operator.save!
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: operator, role: :agent)

channel = Channel::Api.create!(account: account, additional_attributes: {})
inbox = Inbox.create!(account: account, channel: channel, name: 'R12 synthetic inbox — no provider')
InboxMember.create!(inbox: inbox, user: admin)
InboxMember.create!(inbox: inbox, user: operator)
offer = AiLeadEmployee::Offer.create!(
  account: account,
  name: 'R12 Synthetic Coaching',
  currency: 'TZS',
  enabled: true,
  configuration: {
    'qualification_mode' => 'enabled',
    'next_step' => { 'kind' => 'answer_only' },
    'questions' => [],
    'budget_ranges' => [],
    'rules' => [{ 'kind' => 'hard_rule', 'field' => 'region', 'operator' => 'eq', 'value' => 'TZ' }],
    'score_weights' => {},
    'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
  }
)

reviews = [
  ['R12 Refund Lead', 'Can I get a refund if I am not ready to start?', :sensitive_question],
  ['R12 Fit Lead', 'I live outside the configured region. Is this still a fit?', :qualification_blocker]
].map.with_index do |(name, question, reason), index|
  contact = Contact.create!(account: account, name: name, identifier: "r12-synthetic-lead-#{index + 1}")
  contact_inbox = ContactInbox.create!(inbox: inbox, contact: contact, source_id: "r12-synthetic-lead-#{index + 1}")
  conversation = Conversation.create!(
    account: account,
    inbox: inbox,
    contact: contact,
    contact_inbox: contact_inbox,
    assignee: operator,
    offer: offer,
    status: :open,
    control_state: :human_active
  )
  message = conversation.messages.create!(
    account: account,
    inbox: inbox,
    sender: contact,
    message_type: :incoming,
    content: question
  )
  HumanReviewRequest.create!(
    account: account,
    conversation: conversation,
    lead_message: message,
    assigned_user: operator,
    reason: reason,
    question: question,
    alert_recipients: [],
    alert_deliveries: []
  )
end

handoff_contact = Contact.create!(account: account, name: 'R12 Sales Handoff Lead', identifier: 'r12-synthetic-handoff-lead')
handoff_contact_inbox = ContactInbox.create!(inbox: inbox, contact: handoff_contact, source_id: 'r12-synthetic-handoff-lead')
handoff_conversation = Conversation.create!(
  account: account,
  inbox: inbox,
  contact: handoff_contact,
  contact_inbox: handoff_contact_inbox,
  assignee: operator,
  offer: offer,
  status: :open,
  control_state: :human_active
)
handoff_conversation.messages.create!(
  account: account,
  inbox: inbox,
  sender: handoff_contact,
  message_type: :incoming,
  content: 'I agreed to a sales call, but this Lead may not be ready after all.'
)
handoff_qualification = LeadQualification.create!(
  account: account,
  contact: handoff_contact,
  offer: offer,
  quality: :highly_qualified,
  follow_up_state: :human_review,
  score: 88,
  reasons: ['Lead agreed to a sales handoff'],
  missing_signals: [],
  evidence_snapshot: { 'sales_call_agreement' => { 'typed_value' => true, 'polarity' => 'positive' } },
  configuration_version: offer.configuration_version,
  last_evaluated_at: Time.current
)
handoff = LeadHandoff.create!(
  account: account,
  contact: handoff_contact,
  conversation: handoff_conversation,
  lead_qualification: handoff_qualification,
  assignee: operator,
  alert_type: AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE,
  qualification_snapshot: {
    'quality' => handoff_qualification.quality,
    'score' => handoff_qualification.score,
    'reasons' => handoff_qualification.reasons,
    'missing_signals' => [],
    'evidence' => handoff_qualification.evidence_snapshot
  },
  alert_recipients: [],
  alert_deliveries: [],
  handed_off_at: Time.current
)

puts({
  database: database,
  account_id: account.id,
  operator_email: operator.email,
  admin_email: admin.email,
  offer_id: offer.id,
  offer_configuration_version: offer.configuration_version,
  offer_configuration_digest: Digest::SHA256.hexdigest(canonical_json(offer.reload.configuration)),
  handoff: {
    id: handoff.id,
    conversation_id: handoff.conversation_id,
    conversation_display_id: handoff.conversation.display_id,
    path: "/app/accounts/#{account.id}/conversations/#{handoff.conversation.display_id}"
  },
  reviews: reviews.map do |review|
    {
      id: review.id,
      conversation_id: review.conversation_id,
      conversation_display_id: review.conversation.display_id,
      legacy_path: "/app/accounts/#{account.id}/reviews/#{review.id}"
    }
  end,
  safety: 'Channel::Api only; no provider connection, worker, live send, model call, calendar connection or payment data.'
}.to_json)
