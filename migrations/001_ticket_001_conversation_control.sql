CREATE TABLE business_accounts (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  timezone TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE leads (
  id UUID PRIMARY KEY,
  business_account_id UUID NOT NULL REFERENCES business_accounts(id),
  external_contact_id TEXT,
  name TEXT,
  phone_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_account_id, external_contact_id)
);

CREATE TABLE conversations (
  id UUID PRIMARY KEY,
  business_account_id UUID NOT NULL REFERENCES business_accounts(id),
  lead_id UUID NOT NULL REFERENCES leads(id),
  external_conversation_id TEXT NOT NULL,
  control_state TEXT NOT NULL CHECK (control_state IN ('ai_active', 'handoff_requested', 'human_active', 'ai_paused', 'closed')),
  chatwoot_status TEXT NOT NULL CHECK (chatwoot_status IN ('pending', 'open', 'resolved')),
  current_owner TEXT NOT NULL CHECK (current_owner IN ('ai_employee', 'human_operator', 'none')),
  control_version BIGINT NOT NULL DEFAULT 1,
  ai_reply_queued BOOLEAN NOT NULL DEFAULT false,
  follow_up_queued BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_account_id, external_conversation_id)
);

CREATE TABLE webhook_events (
  id UUID PRIMARY KEY,
  business_account_id UUID NOT NULL REFERENCES business_accounts(id),
  provider TEXT NOT NULL,
  external_event_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  event_type TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processing_state TEXT NOT NULL DEFAULT 'accepted',
  UNIQUE (business_account_id, provider, external_event_id)
);

CREATE TABLE scheduled_actions (
  id UUID PRIMARY KEY,
  business_account_id UUID NOT NULL REFERENCES business_accounts(id),
  conversation_id UUID NOT NULL REFERENCES conversations(id),
  action_type TEXT NOT NULL,
  observed_control_version BIGINT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  run_at TIMESTAMPTZ NOT NULL,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
