# R04 two-axis review

The sections below preserve the review history. After the final source review,
[corrected desktop/phone browser acceptance](browser-acceptance.md) passed with
no new code defect. The coordinator independently cleared source `3ade7aa` on
both review axes and verified its evidence/build hashes before browser allocation.

Reviewed the working implementation against integrated R03
`f2b184e1c332f0bf68c31dec460f7e5599657a72`, using separate Standards and Spec
review agents. Both agents performed read-only reviews. They did not run tests
or browser checks; the implementation task owns the attached validation.

## Standards

Initial findings: task-specific test database names prevented standard CI use;
alert cancellation/origin locking omitted explicit tenant scope; recipient
normalization differed between alert creation and current authority checks.

Resolved: concurrency suites use the repository's Rails test-environment guard;
the process provider binds an ephemeral loopback port; both queries scope the
Business Account; shared recipient normalization covers creation and comparison,
including formatted phone numbers. The Standards rereview confirmed all three
findings resolved with no new actionable regression in those fixes.

## Spec

Initial findings: formatted alert recipients could be canceled incorrectly;
malformed template preparation could remain pending indefinitely; independent
workers could send an AI answer before its Channel Greeting.

Resolved: shared normalization, durable preparation failure and fair recovery
ordering, and a greeting acceptance dependency. A follow-up review caught that
historical canceled greetings could block fresh work after resume. The dependency
now matches the current control version; a canonical intent/outbox regression
proves that the old greeting stays canceled and a fresh answer is accepted.
The final Spec rereview confirmed no remaining targeted findings.

Final findings: Standards 0; Spec 0. In-app browser acceptance remains pending
allocation and is recorded separately from code-review findings.


## Coordinator follow-up review

The coordinator independently found three gaps at `99cc25e`: Standards identified
local attachment preparation being classified unknown; Spec identified accepted
messages showing Sent without provider receipts, and rejection racing review-alert
authorization. Each received a canonical red/green regression and a correction.

The follow-up two-axis review also identified stale prepared credentials,
client-supplied receipt evidence, recovery/retry lock inversion and late acceptance
overwriting a concurrent human review decision. Further targeted review required
token-only credential rotation coverage and Channel-before-Conversation locking
consistent with R03 ingress. These are covered by creation APIs, persisted Messages,
signed webhook processing, real provider seams and independent database connections.
The local review agents' final targeted rereviews confirmed both the merged
credential snapshot and consistent Channel → Conversation → delivery lock order,
with no remaining actionable targeted finding. Reviews were read-only; the parent
task owns execution evidence.

The coordinator also explicitly included BookingMutationService's existing direct
provider bypass in R04. Its cancel/reschedule notices now share atomic Message
recording, operator authority and common dispatch/recovery. Separate connection
regressions cover booking preparation competing with dispatch or cancellation,
plus review/booking/handoff revocation. Broader calendar correctness remains R13.

Follow-up final findings: Standards 0; Spec 0. Browser acceptance remains pending.

## Receipt alias correction

The coordinator's final rereview found one remaining P2: camelCase and other
client attribute aliases could survive the snake_case-only filter, then become
trusted-looking receipt fields through the Inbox's deep `useCamelCase` transform.
This could show Sent immediately after acceptance without a provider receipt.

A shared API/model filter now reserves all equivalent top-level delivery,
receipt and external-echo keys. Canonical HTTP coverage exercises ten forms,
including case, separators and Unicode normalization boundaries. A fixture
captured from the actual GET Message responses feeds the real frontend
transform and MessageMeta regression. Ordinary attributes, nested customer data
and trusted provider ingress retain their existing behavior.

Both local review agents completed read-only targeted rereviews of the shared
filter and API-to-component contract. Standards: no actionable findings. Spec:
no concrete remaining defect. The parent task owns the execution evidence.
Browser acceptance remains pending and is not implied by these reviews.

## Browser-discovered live state and grouping corrections

The first actual operator-created send exposed a stale Message instance in the
final live broadcast, and a same-minute group hid the Unknown label. Canonical
broadcast and full MessageList rendering regressions reproduced both defects.

Both local reviewers found the same issue in the initial broadcast correction:
merging fresh data into the old payload retained optional fields, including
removed attachments. A persisted attachment/native soft-delete regression
reproduced that finding. Broadcasts now use fresh account-scoped Message data
and preserve only the event's `previous_changes` and `performer` metadata.

Both final targeted rereviews confirmed the optional-field finding resolved
and reported no remaining targeted findings. Message grouping now preserves
each owned delivery's metadata while ordinary grouping remains covered.
Reviews were read-only; the implementation task owns test and browser evidence.
The corrected desktop/phone browser walkthrough remains pending allocation.

## Delayed creation and optimistic reconciliation

The coordinator found that the original queued Message creation still carried
pending data and could arrive after an accepted/unknown update. The canonical
Message API regression executes that exact serialized creation job last; captured
payloads reproduce both outcomes reverting through the actual Inbox store/list.
Both creation and update jobs now publish current account-scoped Message data,
retaining creation echo correlation and the existing event-metadata whitelist.

Standards and Spec independently found the combined optimistic → outcome →
creation gap in the initial regression set: replacing only the first identity
match left two copies of the persisted Message. The combined real-store/list
tests reproduced accepted and unknown duplication before the correction. The
mutation now reconciles both IDs while keeping the first position and unrelated
same-content replies. Direct creation and persisted-row ordering remain covered.

Both targeted rereviews report zero actionable findings and confirm the combined
ordering tests cover the reported gap. These reviews were read-only; no reviewer
ran validation processes or browser actions. Final findings: Standards 0; Spec 0.
Corrected desktop/phone browser acceptance remains pending allocation.
