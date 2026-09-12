# frozen_string_literal: true

FactoryBot.define do
  factory :lead_follow_up_attempt do
    account
    contact { create(:contact, account: account) }
    stage { :incomplete_qualification }
    attempt_number { 1 }
    admission_state { :unadmitted }
  end

  factory :lead_follow_up do
    account
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, contact: contact) }
    lead_qualification { create(:lead_qualification, account: account, contact: contact) }
    follow_up_attempt do
      association(:lead_follow_up_attempt, account: account, contact: contact, offer_id: lead_qualification.offer_id,
                                           stage: stage, attempt_number: attempt_number)
    end
    after(:create) { |follow_up| follow_up.follow_up_attempt.update!(current_follow_up: follow_up) }

    status { :pending }
    stage { :incomplete_qualification }
    attempt_number { 1 }
    question_text { 'What budget range have you set aside?' }
    content { 'Just following up on this so I can help properly: What budget range have you set aside?' }
    control_version { conversation.control_version }
    scheduled_at { 1.day.from_now }
  end
end
