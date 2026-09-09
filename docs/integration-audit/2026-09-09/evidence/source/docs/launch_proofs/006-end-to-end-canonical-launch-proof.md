# End-to-End Canonical Launch Proof

**Status:** Automated proof added for ticket 006
**Fixed point:** `d877494ebe210db577639823e8afa1f18f518f2a`
**Automated proof:** `spec/requests/ai_lead_employee/end_to_end_canonical_launch_proof_spec.rb`
**Runtime report object:** `AiLeadEmployee::LaunchProofReport`

## Tested seam

The automated proof exercises the canonical V1 launch seam:

```text
verified POST /webhooks/whatsapp/:phone_number
  -> Webhooks::WhatsappEventsJob
  -> Whatsapp::IncomingMessageWhatsappCloudService
  -> tenant-scoped Lead, Conversation, and Inbound Message
  -> visible Channel Greeting
  -> durable AI Orchestration intent
  -> approved relevant Knowledge Item
  -> verified Source References
  -> visible Outbound Message
  -> SendReplyJob and Whatsapp::SendOnWhatsappService
  -> Meta message identifier
  -> delivery status reconciliation
```

The same proof fails if the retired `/webhooks/meta/whatsapp` route or the donor
custom Meta services are used. The retired route is asserted to return `410 Gone`
without creating messages or jobs.

## Reported versions

`AiLeadEmployee::LaunchProofReport#to_h` and `#to_markdown` record the exact
runtime values for:

- tested code version from CI/source environment or `git rev-parse HEAD`;
- WhatsApp channel configuration version: channel id, inbox id, provider,
  phone number id, `updated_at`, and sender class;
- AI provider connection version when configured, or `status: absent` when not
  present in the test environment;
- Knowledge Item versions: id, title, source kind, status, `approved_at`,
  `updated_at`, and verified source reference;
- orchestration intent id, conversation id, outbound message id, source
  references, provider model, deterministic checks, and remaining blockers.

The deterministic ticket-006 proof uses provider model `openai/gpt-5.2` through
the provider-neutral boundary and does not require a stored provider credential
because the provider adapter is stubbed at the external API boundary.

## Deterministic checks

- Canonical launch proof posts a valid signed payload; the related WhatsApp
  controller specs cover invalid-signature rejection.
- Duplicate inbound events create one logical Lead, Contact Inbox, Conversation,
  Inbound Message, Channel Greeting, AI Orchestration intent, Outbound Message,
  and outbox event.
- The Lead message, Channel Greeting, and AI Employee answer remain visible in
  that order.
- The AI answer requires approved same-Business Account Knowledge and verified
  Source References.
- The outbound message is delivered through the existing WhatsApp sender and
  stores Meta's message id.
- Delivery status webhooks reconcile onto the persisted Outbound Message without
  creating a second orchestration intent.
- Retired custom Meta ingestion, sender, text client, and inline auto-reply
  services are not called.
- Stale jobs after human takeover, assignment, pause, resolution, WhatsApp
  coexistence echo, and explicit resume cannot create automated outbound text.
- Provider authentication failure, timeout, rate limit, invalid response, and
  provider-requested review create safe Review Requests with no fabricated
  fallback.
- Cross-tenant access is denied for Leads, Conversations, Knowledge Items,
  Review Requests, provider configuration, and orchestration records.

## Test number status

No live Meta test number, app secret, access token, or provider credential was
provided with this ticket. The launch proof therefore records
`test_number_status: absent` and does not claim a live Meta test.

## Human verification path

1. Configure the Meta test number callback URL to
   `/webhooks/whatsapp/:phone_number` for the target `Channel::Whatsapp` phone
   number.
2. Confirm `/webhooks/meta/whatsapp` is not configured in Meta and still returns
   `410 Gone`.
3. Send a test text message from the Meta test recipient to the configured test
   number.
4. In the owned inbox, confirm the correct Business Account, Lead, Conversation,
   Inbound Message, visible Channel Greeting, AI Employee Outbound Message, and
   verified Source References.
5. Confirm the Outbound Message stores Meta's message id.
6. Send or wait for Meta delivery status webhooks and confirm sent, delivered,
   read, or failed status reconciles onto that same Outbound Message without a
   second AI decision.

## Remaining blockers

- Live Meta test-number verification remains pending until credentials and a
  configured test number are available.
- Stored AI Provider Connection verification remains environment-dependent
  because Active Record encryption keys must be configured before credentials
  can be saved.
