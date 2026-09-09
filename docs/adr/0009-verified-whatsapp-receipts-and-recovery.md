---
status: accepted
---

# Persist verified WhatsApp receipts and recover canonical processing

R03 (#20) extends ADRs 0005 and 0006 on the integrated R01/R02 baseline
`5577a37ddae5f6d08b33b0b33aefe6d933d7003c`. The supported production path
remains `/webhooks/whatsapp/:phone_number`, the owned CE channel, Conversation,
Message and outbound sender. No alternate Meta runtime is restored.

## Connection and authority

V1 permits one `whatsapp_cloud` channel per Account, enforced by PostgreSQL and
the model. Other CE source remains gated. An administrator configures the
connection directly in the persistent Settings layout. API tokens, signing
secrets, verification tokens and registration PINs move from plaintext JSON
into an encrypted channel credential field. Nonsecret routing identifiers stay
queryable. Existing credentials migrate only with configured Active Record
encryption. Legacy plaintext business-management tokens are also encrypted;
already encrypted tokens are preserved. Conflicting existing Cloud connections fail migration explicitly
instead of deleting business data. Credential writes fail without encryption.

Browser responses use an allowlist of identifiers and configured/health status,
never stored credentials. Saved credentials can be retained on updates without
being returned to the form. Webhook registration uses the server-held verification
token, removing the old FinishSetup token-reflection dependency.

Every supported Cloud callback requires raw-body HMAC verification, including
manual setup. Each supported entry/change must resolve to the stored number ID
and Business Account and validate against that connection's signing authority.
An envelope authenticated for one connection cannot authorize another app's
channel. Unknown or conflicting routing is rejected before acceptance. Missing
signing configuration is an incomplete connection, never ready.

## Receipt, normalization and recovery

Persist the authenticated raw envelope and its verified routing bindings before
HTTP success. A unique body digest deduplicates identical receipts. This internal
receipt is not exposed through customer APIs because an envelope may cover more
than one Business Account. Parsing into logical events is replayable and records
every supported entry, change, message, echo and delivery status.

Logical events are tenant/channel scoped and have database-enforced unique keys.
Messages and echoes use provider message identity; statuses include provider
identity, status and provider time. The event row is locked while its CE records,
Control State changes and eligible AI intent are committed atomically. Redis may
schedule work, but does not establish durable completion. A contact-card message
may intentionally create several CE Message rows under one logical event.

V1 serializes normalization with a PostgreSQL channel row lock as well as the
event lock. This deliberately trades per-number parallelism for correct first
Conversation creation across concurrent receipts and alternate sender IDs.
Failure releases both locks through transaction rollback. Revisit throughput
with measured demand before replacing this with narrower identity locks.

Keep provider time, receipt time and processing time separately. R04 uses these
for delivery correlation and the trustworthy customer response window. Match
each message to its own sender/contact, including CE supported alternate
WhatsApp identifiers; never reuse a batch's first contact for other senders.

Queue creation is best effort after durable acceptance. A recurring recovery job
resubmits unexpanded receipts, unfinished events and pending AI intents. Unexpanded
receipts have their own bounded batch; normalized events are ordered by their
next attempt or original creation time so old unresolved delivery updates cannot
monopolize recovery ahead of waiting messages. Event
failures have persisted safe codes, attempts and retry times. Unknown delivery
IDs remain pending correlation and are retried after local outgoing identity
becomes available; R04 must retain this recovery boundary when changing sends.

Delivery history remains immutable. Project sent/delivered/read without
regressing delivered/read on late events. Record failures independently of the
success ordering and preserve provider timestamps; a failure cannot erase
evidence of delivery/read. Status lookup is scoped to the verified channel.

## Acceptance and external boundary

Test the setup API/UI, canonical signed webhook, persisted Conversations,
database concurrency and process/queue failure recovery with isolated synthetic
services and an external fake Meta provider. Preserve Channel Greeting and
coexistence behavior. No production credentials, live recipients or launch
approval are needed for this local acceptance. Actual Meta test assets and
supervised delivery are a later explicitly authorized proof.
