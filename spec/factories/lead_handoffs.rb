# frozen_string_literal: true

FactoryBot.define do
  factory :lead_handoff do
    account
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, contact: contact) }
    lead_qualification { create(:lead_qualification, account: account, contact: contact) }
    alert_type { AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE }
    status { :open }
    qualification_snapshot { { 'quality' => 'highly_qualified' } }
    alert_recipients { [] }
    alert_deliveries { [] }
    handed_off_at { Time.current }
  end
end
