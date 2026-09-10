---
status: accepted-for-r05-implementation
---

# Record evidenced automated-contact consent before any automated response

R05 (#22) builds on canonical verified WhatsApp ingress in ADR 0009 and the
owned outbound authorization point in ADR 0011. Explicit Lead withdrawal is a
Business Account/Lead consent decision. It is separate from Qualification,
Follow-up State, Control State, assignment, and Inbox Conversation Status.

## Decision

Canonical incoming processing calls one automated-contact consent module after
the trusted Inbound Message is persisted and before any Channel Greeting or AI
Orchestration intent is recorded. The module deterministically recognizes clear
English, Swahili, and mixed-language withdrawal. It rejects unrelated refusals,
negated withdrawal, quoted examples, and informational questions. Recognition
does not use the AI Provider.

Withdrawal appends immutable Consent Evidence and creates or refreshes the
unique active `lead_follow_up_opt_outs` projection used by existing R04 dispatch
checks. Evidence includes the source Message and Conversation, trusted provider
event identity and time, observed wording, recognizer version, recording actor,
and recorded time. A replay of the same source Message has no second effect; a
distinct later withdrawal is retained. Consent mutation never closes or
re-evaluates Qualification.

Current permission is derived from consent-event chronology using provider
occurrence time and event ID as a deterministic tie-breaker. A delayed older
withdrawal is retained as evidence but cannot replace a newer grant as the
current state.

The withdrawal transaction locks the Channel and every owned Conversation for
the Lead in ID order, then invalidates pending or claimed automated outbound
deliveries and pending or processing AI intents. It advances their Control State
versions without changing Control State or assignment. The service returns a
stopped result, so the ingress caller records no greeting or AI intent. The
incoming Message remains visible. Mixed stop and support text has the same
precedence and no automated acknowledgment.

R04's transition from claimed to dispatching is the provider authorization
point. A withdrawal committed first prevents the HTTP request. Authorization
committed first may already reach the provider, so its accepted or unknown
outcome remains unchanged; the withdrawal blocks later work. Recovery and
restart never convert consent evidence into permission or revive canceled work.

Pending follow-up rows are left for their existing delivery worker so the stop
transaction never reverses the follow-up-to-Conversation lock order. That worker
rechecks the active suppression and cancels the attempt before recording an
Outbound Message. Already recorded follow-up Messages are canceled through the
shared delivery invalidation and final dispatch check.

## Re-consent

Only an administrator may record re-consent in V1. The mutation selects a newer
verified Lead-authored Inbound Message that explicitly permits automated contact
again and supplies the expected current withdrawal evidence. The server checks
Business Account, Lead, Conversation, trusted source, wording, freshness, and
concurrent withdrawal before appending grant evidence and removing only the
active projection. Evidence already used for a consent event is rejected rather
than treated as a successful mutation replay.

Re-consent sends nothing and does not resume AI. Generic acknowledgment, import,
Lead edit, or AI resume cannot grant consent. Previously canceled, failed,
unknown, accepted, or pre-withdrawal work is never revived. Only a fresh later
eligible event can create new automated work under every other current gate.

## Access and presentation

Conversation and Lead detail payloads expose a current automated-contact status
independently of Qualification. Administrators and Human Operators with access
to the source Conversation may see its evidence and open its Message. An
operator who can see another Conversation for the Lead sees the current state
but receives no source identifiers, wording, or timestamps from an inaccessible
Conversation. Both withdrawn and granted states retain their visible evidence
when the viewer is authorized. Reassignment and membership revocation apply to
reads and realtime updates.

## Acceptance

Acceptance uses the signed canonical webhook and receipt/event jobs, real
Account/Lead/Conversation/Message records, independent database workers, R04's
common sender and recovery jobs, an isolated provider HTTP adapter, authorized
Conversation and Lead HTTP reads, the administrator re-consent mutation, and
the existing Inbox/Lead Vue paths in the allocated in-app browser. No live
customer messaging, provider credentials, deployment, or launch activation is
required.
