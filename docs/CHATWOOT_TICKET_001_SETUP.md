# Ticket 001 Chatwoot Setup

This implementation consumes Chatwoot AgentBot webhooks at:

`POST https://<ai-lead-employee-domain>/api/chatwoot/webhooks`

Configure an AgentBot in the relevant Chatwoot account with that URL and the same
secret used for `CHATWOOT_WEBHOOK_SECRET`. Attach the bot to the WhatsApp inbox.
Chatwoot sends `X-Chatwoot-Delivery`, `X-Chatwoot-Timestamp`, and
`X-Chatwoot-Signature`; the signature is HMAC SHA-256 over `timestamp.body`.

The outgoing-message adapter uses the Chatwoot account API endpoint and requires
`CHATWOOT_BASE_URL`, `CHATWOOT_ACCOUNT_ID`, and `CHATWOOT_API_TOKEN`.

## Smoke Test

1. Apply `migrations/001_ticket_001_conversation_control.sql` to the AI Lead Employee PostgreSQL database.
2. Set the environment variables in `.env` from `.env.example`.
3. Run the application and send a WhatsApp message to the configured Chatwoot inbox.
4. Confirm the operator screen shows `ai_active`, `pending`, and `ai_employee`.
5. Assign a Human Operator or send a human reply in Chatwoot.
6. Confirm the operator screen changes to `human_active`, `open`, and `human_operator`.
7. Trigger a previously queued test reply and confirm it is blocked rather than sent.

The webhook field names and signature scheme above were verified against the
pinned Chatwoot v4.17.0 source. The live smoke test remains required because it
depends on the actual Chatwoot deployment and WhatsApp credentials.
