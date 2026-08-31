# frozen_string_literal: true

class AiLeadEmployee::Evaluation::ScenarioCatalog
  ScenarioNotFound = Class.new(StandardError)

  SCENARIOS = [
    {
      key: 'approved_answer',
      name: 'Approved answer with qualification',
      description: 'The AI Employee answers only from approved Knowledge Items and asks the next qualification question.',
      required: true,
      messages: [
        {
          event_id: 'approved-answer-1',
          type: 'text',
          body: 'Do you offer AI employees? I run an agency.',
          expected: {
            refusal_reason: nil,
            quality: 'low_qualified',
            handoff_decision: 'continue_ai',
            booking_decision: 'not_eligible',
            follow_up_decision: 'schedule_incomplete_qualification',
            no_real_send: true
          }
        }
      ]
    },
    {
      key: 'unknown_question',
      name: 'Unknown question requires review',
      description: 'Unsupported questions create a Review Request instead of fabricated fallback content.',
      required: true,
      messages: [{ event_id: 'unknown-question-1', type: 'text', body: 'Can you build rockets?',
                   expected: { review_request_reason: 'no_approved_knowledge', no_real_send: true } }]
    },
    {
      key: 'sensitive_question',
      name: 'Sensitive question requires review',
      description: 'Legal, medical, guarantee, and liability questions are held for a Human Operator.',
      required: true,
      messages: [{ event_id: 'sensitive-question-1', type: 'text', body: 'Can you give legal advice and guarantee results?',
                   expected: { review_request_reason: 'sensitive_question', no_real_send: true } }]
    },
    {
      key: 'angry_lead',
      name: 'Angry lead requires review',
      description: 'Angry or complaint language stops automated answering.',
      required: true,
      messages: [{ event_id: 'angry-lead-1', type: 'text', body: 'I am furious and upset about this terrible service',
                   expected: { review_request_reason: 'angry_question', no_real_send: true } }]
    },
    {
      key: 'unsupported_media',
      name: 'Unsupported media requires review',
      description: 'Unsupported WhatsApp media is not guessed or delivered as an AI answer.',
      required: true,
      messages: [{ event_id: 'unsupported-media-1', type: 'audio', body: nil,
                   expected: { review_request_reason: 'unsupported_media', no_real_send: true } }]
    },
    {
      key: 'duplicate_event',
      name: 'Duplicate provider event',
      description: 'A duplicated provider event has one logical effect.',
      required: true,
      messages: [
        { event_id: 'duplicate-event-1', type: 'text', body: 'Do you offer AI employees?',
          expected: { duplicate_ignored: false, no_real_send: true } },
        { event_id: 'duplicate-event-1', type: 'text', body: 'Do you offer AI employees?',
          expected: { duplicate_ignored: true, selected_answer: nil, no_real_send: true } }
      ]
    },
    {
      key: 'stale_ai_job',
      name: 'Stale AI job',
      description: 'A delayed orchestration intent is blocked after the Control State version changes.',
      required: true,
      messages: [{ event_id: 'stale-ai-job-1', type: 'text', body: 'Do you offer AI employees?', stale_before_ai: true,
                   expected: { blocked_reason: 'stale_control_version', no_real_send: true } }]
    },
    {
      key: 'human_takeover',
      name: 'Human takeover',
      description: 'A Human Operator takeover prevents automated sending.',
      required: true,
      messages: [{ event_id: 'human-takeover-1', type: 'text', body: 'Do you offer AI employees?', takeover_before_ai: true,
                   expected: { blocked_reason: 'incompatible_control_state', no_real_send: true } }]
    },
    {
      key: 'coexistence_echo',
      name: 'WhatsApp coexistence echo',
      description: 'A human echo from WhatsApp Business coexistence blocks the AI Employee.',
      required: true,
      messages: [{ event_id: 'coexistence-echo-1', type: 'text', body: 'Do you offer AI employees?', coexistence_echo_before_ai: true,
                   expected: { blocked_reason: 'human_reply_after_trigger', no_real_send: true } }]
    },
    {
      key: 'opt_out',
      name: 'Opt-out',
      description: 'A stop request records opt-out and produces no automated answer.',
      required: true,
      messages: [{ event_id: 'opt-out-1', type: 'text', body: 'stop',
                   expected: { opt_out_recorded: true, selected_answer: nil, no_real_send: true } }]
    },
    {
      key: 'booking_conflict',
      name: 'Booking conflict',
      description: 'A highly qualified Lead cannot be booked into an unavailable calendar slot.',
      required: true,
      messages: [
        {
          event_id: 'booking-conflict-1',
          type: 'text',
          body: 'I need more leads now. I am the owner of the agency and can spend $2500.',
          force_booking_conflict: true,
          expected: { quality: 'highly_qualified', booking_decision: 'booking_unavailable', no_real_send: true }
        }
      ]
    },
    {
      key: 'tenant_isolation',
      name: 'Tenant isolation',
      description: 'Cross-account orchestration records are blocked before an answer can be delivered.',
      required: true,
      messages: [{ event_id: 'tenant-isolation-1', type: 'text', body: 'Do you offer AI employees?', tenant_mismatch_before_ai: true,
                   expected: { blocked_reason: 'tenant_scope_mismatch', no_real_send: true } }]
    }
  ].freeze

  def self.all
    SCENARIOS.map(&:deep_dup)
  end

  def self.required_keys
    SCENARIOS.select { |scenario| scenario[:required] }.pluck(:key)
  end

  def self.find!(key)
    all.find { |scenario| scenario[:key] == key.to_s } || raise(ScenarioNotFound, "Unknown evaluation scenario: #{key}")
  end
end
