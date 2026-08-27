# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_document do
    account
    title { 'Everything about Online Profits' }
    body { 'Online Profits helps service businesses grow with strategy, automation, and reporting.' }
    status { :published }
    used_by_ai_employee { true }
    general_question_access { true }
    offer_ids { [] }
    sensitive_topics { %w[pricing refunds guarantees] }
    revisions { [] }
    published_at { Time.current }
  end
end
