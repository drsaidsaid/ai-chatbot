# frozen_string_literal: true

FactoryBot.define do
  factory :booking do
    account
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, contact: contact) }
    lead_qualification { create(:lead_qualification, account: account, contact: contact, quality: :highly_qualified) }
    calendar_id { 'sales-calendar' }
    provider { 'local_calendar' }
    status { :confirmed }
    starts_at { 1.day.from_now.change(usec: 0) }
    ends_at { starts_at + 30.minutes }
    timezone { 'Africa/Dar_es_Salaam' }
    qualification_evidence_ids { [] }
    qualification_snapshot { { 'quality' => 'highly_qualified' } }
    calendar_event_payload { {} }
  end
end
