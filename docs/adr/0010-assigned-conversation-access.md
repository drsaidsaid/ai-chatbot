---
status: accepted
---

# Fixed roles and assigned Conversation access

R06 implements the approved assigned-only Team Member requirement on the owned
CE User/AccountUser foundation. Product Admin maps to `administrator`; Team
Member maps to `agent`. No role or tenancy table replacement is needed.

An active account membership is required at every authorization boundary. Admins
see all records within their Business Account. Team Members see only Conversations
whose current `assignee_id` is their User ID; inbox, team and participant membership
do not grant access. Only Admins assign/reassign work or manage business settings.

A Lead's identity can be read/edited when at least one Conversation is assigned
to the member. Related Conversations, messages, attachments, reviews, bookings,
follow-ups and evidence remain Conversation-scoped. Account-wide Qualification
aggregates must not disclose facts derived from inaccessible Conversations. When
a Lead has an inaccessible Conversation, the member sees permitted evidence but
no combined Qualification; the AI's stored evaluation is not rewritten for display.
Admin-only import/export and knowledge approval stay Admin-only. Dashboard Inbox
reads expose only transport details needed to reply; Inbox settings and public API
credentials stay Admin-only. Contact channel metadata is restricted to the member's
assigned Conversations. Realtime dashboard payloads strip contact widget socket
credentials, which would otherwise bypass the member's assignment boundary.

Requests, query counts/search, attachment downloads, realtime recipients and
queued deliveries must check current membership/assignment. Reassignment removes
old access; a content-free invalidation can tell clients to clear stale data.
Revoking one account membership must preserve a user's access to other accounts.

Explicitly resuming the AI from Human Active clears `assignee_id` as the
Conversation returns to AI Active. This keeps ownership and access aligned: the
Team Member who handed control back returns to their assigned Conversation list,
while an administrator retains Business Account-wide visibility. Resume changes
only future eligibility. Previously canceled orchestration intents and outbound
deliveries remain terminal, no Message is created by the control action, and
Automated Contact Consent remains an independent dispatch requirement.
Public control requests recheck the actor's current account membership and
Conversation assignment inside the same Conversation row lock that changes
control. A request authorized before reassignment cannot clear or alter the new
operator's ownership.
Takeover and resolution also change the owned Inbox status inside that locked
transition. They persist Inbox status, Control State, assignment, control version,
and pending-work invalidation as one transaction. Pause, resume and handoff reject
a resolved Conversation regardless of its Control State, and handoff begins only
from AI Active, so the public API cannot reopen its control lifecycle indirectly.
Human pending and snoozed changes also recheck access while holding the
Conversation lock. Dashboard action responses carry their originating account;
the store discards a delayed response after account navigation, including when
both accounts reuse the same Conversation display ID.
Bot handoff creates a uniquely keyed Outbox Event in the locked transition. The
dispatch job locks that record and marks it delivered, so failed, duplicate and
concurrent jobs cannot repeat the state transition. Notification and reporting
consumers claim unique database receipts with their effects so replay after a
worker interruption cannot apply an effect twice. The existing scheduled outbox
dispatcher also recovers committed handoffs whose immediate enqueue is lost.
Bot-triggered handoff additionally requires the authenticated bot to remain the
exact Conversation assignee with an active association to that Inbox; these
facts are rechecked inside the Conversation lock. Recovery dispatches with the
Outbox Event creation time so reporting reflects the transition rather than the
later recovery run.

Queued revocation cleanup must serialize its membership recheck and mutations
with invitation creation under the Account row lock. Cleanup uses
`FOR NO KEY UPDATE`: it still conflicts with AgentBuilder's `FOR UPDATE`, but
allows the `FOR KEY SHARE` check required when Conversation-locked work inserts
a HumanReviewRequest referencing the Account. This avoids a circular wait between
cleanup's Conversation unassignment and review creation without weakening the
membership check. Regression covers both invitation/cleanup orderings and the
real two-connection review foreign-key interaction.

The acceptance seams are the authorized R06 HTTP invitation/session/resource
paths, asynchronous realtime/export boundaries and actual Vue/browser user paths.
Tests use two accounts, several assignments, mixed-access Conversations for one
Lead and changes between queueing and execution. External email is captured by
local test adapters. Provider delivery itself remains R03/R04/R18 scope.

## Read-only browser media session

Native image/audio/download requests cannot add the dashboard's CE authorization
headers. An authenticated CE request therefore writes an encrypted, HttpOnly,
SameSite=Strict cookie containing the User ID, client ID and existing CE token.
The cookie is accepted only for media reads (and socket identity); it cannot
authorize API mutations. Each read validates the original token against current
CE User session state, then resolves current account membership and assignment.
Sign-out/session invalidation, reassignment and membership revocation therefore
invalidate stale media cookies/URLs. Responses use private, no-store caching.

Dashboard attachment URLs use an authenticated proxy. Legacy ActiveStorage blob,
representation and disk routes must enforce the same boundary for protected
attachments; a signed storage URL alone is insufficient dashboard authorization.
Provider retrieval is a separate, short-lived, signed capability for a specific
outgoing non-private WhatsApp attachment. It must never appear in dashboard
payloads and must not inherit a browser's cookie. The existing server sender
obtains that capability through Attachment#download_url. Its endpoint rechecks
the attachment/message/account; no public access to arbitrary blobs is granted.
R03/R04 retain WhatsApp delivery authority, idempotency and final-send gates.

## Retained CE action paths

Macros are unsupported in V1, so all dashboard macro HTTP endpoints return an
unavailable response for both roles. Pre-existing queued macros may execute
only for a current Admin with access to that macro and Business Account; member
macros cannot bypass assignment, messaging or webhook restrictions.

Lead merges are destructive and require current Admin access before either
record is resolved. Contact bulk label jobs resolve the actor's current
AccessScope.contacts when executing. Bulk deletion additionally requires current
Admin membership, so demotion or revocation after enqueueing cancels deletion.
