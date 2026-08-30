# frozen_string_literal: true

module AiLeadEmployee::Orchestration::DecisionPlaceholder
  ACTOR_TYPE = 'ai_employee'
  BLOCK_REASONS = {
    assigned_to_human_operator: 'assigned_to_human_operator',
    human_reply_after_trigger: 'human_reply_after_trigger',
    incompatible_control_state: 'incompatible_control_state',
    ineligible_inbox_status: 'ineligible_inbox_status',
    no_approved_knowledge: 'no_approved_knowledge',
    opted_out: 'opted_out',
    provider_failure: 'provider_failure',
    source_unverified: 'source_unverified',
    stale_knowledge: 'stale_knowledge',
    stale_control_version: 'stale_control_version',
    tenant_scope_mismatch: 'tenant_scope_mismatch'
  }.freeze
  DELIVERY_BOUNDARY = 'outbox'
  OUTBOUND_INTENT_STATUS = 'grounded_answer'
  OUTBOX_EVENT_TYPE = 'ai_employee.outbound_intent_recorded'
end
