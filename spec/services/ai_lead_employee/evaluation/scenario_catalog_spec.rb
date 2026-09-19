# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Evaluation::ScenarioCatalog do
  it 'covers the required reusable V1 launch scenarios' do
    expect(described_class.required_keys).to include(
      'approved_answer',
      'safe_swahili_language_question',
      'unknown_safe_question',
      'controlled_claim_requires_review',
      'sensitive_question',
      'angry_lead',
      'unsupported_media',
      'duplicate_event',
      'stale_ai_job',
      'human_takeover',
      'coexistence_echo',
      'opt_out',
      'booking_conflict',
      'tenant_isolation'
    )
  end

  it 'covers the new response policy without weakening controlled business claims' do
    swahili = described_class.find!('safe_swahili_language_question')
    unknown = described_class.find!('unknown_safe_question')
    controlled_claim = described_class.find!('controlled_claim_requires_review')

    expect(swahili.dig(:messages, 0, :body)).to include('Kiswahili')
    expect(swahili.dig(:messages, 0, :expected)).to include(
      review_request_reason: nil,
      blocked_reason: nil,
      handoff_decision: 'continue_ai',
      no_real_send: true
    )

    expect(unknown.dig(:messages, 0, :expected)).to include(
      selected_answer: 'Are you asking about this business or one of its Offers?',
      review_request_reason: nil,
      blocked_reason: nil,
      handoff_decision: 'continue_ai',
      no_real_send: true
    )
    expect(unknown.dig(:messages, 1, :expected)).to include(
      review_request_reason: 'no_approved_knowledge',
      blocked_reason: 'no_approved_knowledge',
      handoff_decision: 'blocked',
      no_real_send: true
    )

    expect(controlled_claim.dig(:messages, 0, :expected)).to include(
      review_request_present: true,
      selected_answer: 'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.',
      no_real_send: true
    )
  end
end
