---
status: accepted
---

# Own WhatsApp dispatch and recover without guessing provider acceptance

R04 (#21) builds on ADRs 0005, 0006 and 0009. A Message has one durable
WhatsApp Outbound Delivery, recorded in the same transaction as its creation.
This delivery owns provider dispatch for human replies, Channel Greetings,
AI answers, follow-ups and operator alerts. Domain outbox events retain their
decision role; every route to the existing CE WhatsApp sender joins the same
Message delivery. No second provider or media download path is introduced.

## Ownership and the dispatch boundary

The delivery states are pending, claimed, dispatching, accepted, unknown,
failed and canceled. PostgreSQL serializes claims and persists an unpredictable
owner token and expiry. Only the owner may cross from claimed to dispatching.
Expired delivery and model claims can be recovered up to three attempts. Dispatching work
is never leased to another sender: after expiry it becomes unknown. A late
response from that original owner may establish acceptance.

Immediately before dispatch, a short transaction re-reads the delivery,
Message, Conversation, active Account, sender membership/assignment, Control
State/version, recorded opt-out, launch permission and channel configuration.
It commits dispatching before making the bounded HTTP call. That commit is the
authorization point: a control action committed first cancels the unsent work;
a control action after it cannot retract a request already authorized for the
provider. Neither model work nor provider HTTP holds the Conversation lock.
Takeover remains prompt even if the remote service stops responding.

The owner prepares the complete payload and dispatch-time media capability while
claimed, then validates that its connection snapshot still matches the current
channel before authorization. Local preparation exceptions become failed, with
no dispatch timestamp. Timeout or persistence uncertainty after the HTTP boundary
remains unknown. Originating review/booking/handoff rows serialize authority
mutations with the authorization commit. Unknown-review creation follows the
Conversation → delivery order; late acceptance preserves completed human review
decisions. Locks are released before HTTP.
Authorization follows the canonical ingress order: Channel → owned Conversations
in ID order → delivery → originating authority. The snapshot includes the merged
encrypted credentials in memory only. Conversation `NO KEY UPDATE` locks still
serialize control mutations while allowing booking preparation's foreign-key
inserts to finish; a waiting dispatch or cancellation cannot deadlock that path.

Human replies require a current account membership; members must still be the
Conversation assignee and administrators retain account-wide reply access,
matching ADR 0010's contract without adopting its unintegrated implementation.
Automated Lead-facing replies require AI Active, open, unassigned, unchanged
control version, current launch permission and no recorded opt-out. A private
human note invalidates already pending automation; resuming permits future
inbound work and never revives canceled replies. Operator alerts use their
originating review/handoff authority rather than the notification Conversation's
deliberately human-active control state. Channel Greetings remain configured
first responses and receive the same automation eligibility checks. Automated
answers wait for a greeting from the same control version to be accepted; an
old canceled greeting cannot block fresh work after explicit resume.

## Outcomes and recovery

Provider acceptance requires a usable provider Message ID. Accepted is separate
from the provider's sent/delivered/read history. A definite rejection or local
eligibility failure is failed or canceled. A timeout, malformed success, crash
after dispatch begins, or failure to persist the provider response is unknown.
Unknown outcomes create one local Review Request and cannot be automatically
resent or passed through the generic retry endpoint. We do not assert that Meta
provides an exactly-once request API. Known provider IDs reconcile through R03's
channel-scoped receipt history and shared monotonic MessageStatusProjector.
The Inbox displays accepted/awaiting delivery until projector-owned receipt
evidence exists; creating a Message cannot supply this evidence through client
content attributes. Provider sent/delivered/read/failed projections survive reload.
Without reliable correlation, human review is the terminal recovery action.

A recurring recovery job repairs lost enqueue operations, expired pre-dispatch
claims and abandoned model claims in bounded batches with per-record error
isolation. A preparation exception becomes a durable failed outcome before any
provider dispatch, and visited pending rows move behind later recovery work so
one unavailable queue or malformed record cannot monopolize the batch.
Canonical ingress records the configured greeting before marking its
event processed, preserving the inbound → greeting → AI-answer sequence and
recovering a crash before the old after-commit greeting hook. Old untracked
outgoing messages are not blindly replayed on upgrade; missing provider evidence
is classified as unknown. Credentials and content never enter recovery logs.

Model processing claims an intent and snapshots its authority in a short
transaction, performs remote work outside locks, then revalidates its owner,
control version, current permissions and source authority before committing
the decision, Message and domain outbox. A lost or canceled claim cannot commit
late output. R03's verified receipt-ID queue boundary and provider timestamps
remain authoritative.

Booking cancel/reschedule notices are persisted with the initiating Human Operator
inside the booking mutation transaction, under Conversation → Booking ordering.
Each recorded mutation identity stores its notice Message ID, and the booking's
confirmation Message identity is that local ID. Duplicate mutations reuse the
committed result; enqueue loss is repaired by Outbound Delivery recovery. These
notices use the common sender and current operator eligibility, with the same
pending/failed/unknown semantics as an Inbox reply. R13 retains broader calendar
reservation, rescheduling and historical mutation repair responsibilities.
In particular, a historical mutation already marked applied without a recorded
notice Message ID must be reconciled from provider/history evidence, not blindly
resent by reusing the mutation key. Existing reservation overlap, availability,
calendar provider work and cross-mutation scheduling semantics remain R13 scope.

## Acceptance

The authorized test seams are canonical Rails jobs/message APIs, independent
PostgreSQL workers and process crashes, isolated fake provider HTTP, and the
existing Inbox's delivery indicators/retry actions. Browser proof uses the
allocated in-app tab. External customer messaging and live launch are excluded.
