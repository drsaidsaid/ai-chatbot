# R13 Google Calendar booking implementation

Baseline: `b4be1a684dec9006b46afae967a2abfa75f933db`

Google Calendar is the V1 booking provider. The account connection uses narrow
Calendar event and free/busy OAuth scopes, encrypted access and refresh tokens,
a signed single-use callback state, and explicit disconnected, connected,
permission-error, and connection-error states. No live OAuth grant was used in
R13 verification.

Availability is the intersection of Google free/busy, the account timezone,
weekdays and local hours, date exceptions, meeting duration, buffers, minimum
notice, and active local bookings. A connected empty calendar is a successful
empty busy set; provider failures never appear as free time.

The conversation workflow offers a currently available slot through the
canonical human WhatsApp sender. The outgoing proposal records the selected
Offer revision and exact timestamp. An immediate affirmative Lead reply records
Offer-scoped agreement evidence for that timestamp. Booking requires that
evidence and source Message, the selected Offer's current qualification
assessment when qualification is enabled, and the same requested timestamp.
A stored contact email is never used for an invitation; the operator must mark
an attendee email as voluntarily supplied.

Create uses a deterministic Google event ID. Create, reschedule, and cancel
persist their operation state and idempotency key, call Google outside the
database lock, and publish local confirmed state and WhatsApp side effects only
after a conclusive provider result. Pending and provider-unknown records hold
their time in the PostgreSQL exclusion constraint. Unknown results are visible
and have an explicit reconciliation action. R04 remains the authority for
outbound booking notices.

Free sales calls and free appointments use the same eligibility boundary. A
configured `payment_confirmation` prerequisite fails closed through
`BookingPrerequisiteChecker`; R28 owns the future verified payment adapter.

## Verification boundary

All provider tests use WebMock contract responses or injected fakes. They cover
connected-empty versus failure, deterministic duplicate create recovery,
update, idempotent delete, concurrent same-slot requests, unknown create and
mutation reconciliation, and voluntary attendee email behavior. These tests do
not claim a live Google OAuth or Calendar verification.
