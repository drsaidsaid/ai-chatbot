# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Evaluation::ScenarioCatalog do
  it 'covers the required reusable V1 launch scenarios' do
    expect(described_class.required_keys).to include(
      'approved_answer',
      'unknown_question',
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
end
