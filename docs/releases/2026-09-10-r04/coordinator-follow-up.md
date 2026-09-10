# R04 coordinator corrections

The coordinator reviewed `99cc25e` and requested preparation-boundary, accepted
status and review-rejection fixes. It then explicitly added the reachable booking
cancel/reschedule notice bypass. These corrections remain on R04's isolated
branch; browser acceptance and integration are still pending.

## Behavior and evidence

| Boundary | Corrected behavior | Red / green evidence |
| --- | --- | --- |
| Attachment preparation | Both Cloud and 360dialog prepare media locally while claimed. Failure produces `failed/preparation_failed`, zero provider requests, no unknown review and a working authorized Inbox retry. | `preparation-boundary-red.txt`, `preparation-boundary-green.txt`; final suite covers both providers |
| Prepared connection | The complete payload is prepared before final authorization. The merged public/encrypted connection configuration is snapshotted in memory and compared under the Channel lock. Token-only and routing changes cancel the stale request. | `preparation-rotation-red.txt`, `preparation-rotation-green.txt`, `channel-boundary-red.txt`, `channel-boundary-green.txt` |
| Provider acceptance | The Message API persists projector-owned `whatsapp_provider_status`. The actual Inbox displays “Accepted by WhatsApp; awaiting delivery” until provider receipt evidence exists, then preserves sent/delivered/read and failed states. | `acceptance-history-red.txt`, `acceptance-history-green.txt`, `acceptance-ui-red.txt`, `acceptance-ui-green.txt`, `coordinator-vue-final.txt` |
| Receipt authority | New API Messages cannot supply provider receipt fields, provider source IDs or external-echo/accepted claims. Trusted canonical provider ingress remains separate. | `receipt-authority-red.txt`, `receipt-authority-green.txt`, `receipt-echo-red.txt`, `receipt-echo-green.txt` |
| Receipt aliases | The shared API/model boundary strips top-level keys that the Inbox normalizes into reserved delivery/receipt/echo fields, including case, separators and Unicode variants. Ordinary keys and nested customer data survive. Actual accepted GET Message responses feed the real `useCamelCase` and MessageMeta regression. | `receipt-alias-api-red.txt`, `receipt-alias-api-green.txt`, `receipt-alias-ui-red.txt`, `receipt-alias-ui-green.txt` |
| Review rejection | The actual rejection API and alert authorization serialize on the originating review row. Either rejection wins and no request is made, or authorization commits before rejection. Booking/handoff cancellation uses the same record lock. | `review-authority-red.txt`, `review-authority-green.txt`, `booking-locks-green.txt` |
| Late acceptance and recovery | Late acknowledgment records acceptance without replacing an already completed human review decision. Unknown-review creation follows Conversation → delivery order, including recovery competing with the actual retry API. | `reconciliation-locks-red.txt`, `reconciliation-locks-green.txt` |
| Booking mutation notices | Actual cancel/reschedule records one notice attributed to the initiating operator in the mutation transaction. Mutation metadata stores its local Message ID; booking confirmation identity remains that ID after provider acceptance. Duplicate mutation plus lost-enqueue recovery sends once. Failed/unknown states remain authoritative; revoked sender membership cancels before HTTP. | `booking-notice-red.txt`, `booking-notice-green.txt`, `coordinator-ruby-final.txt` |
| Booking preparation | Conversation `NO KEY UPDATE` locks allow existing booking preparation's Message foreign-key inserts to complete while dispatch/cancel waits for the booking record. Control mutations remain serialized. | `booking-locks-red.txt`, `booking-locks-green.txt` |
| Canonical ingress | Authorization locks Channel before Conversations and delivery, matching R03. A signed webhook is persisted, then its real job competes with an outgoing job without reversing lock order. | `channel-boundary-red.txt`, `channel-boundary-green.txt` |

All payload variants on both existing providers yield fully prepared URL, headers
and serialized body to the shared request boundary. Configuration/setup requests
retain their existing paths. Media URLs are generated during worker execution,
which preserves R06's dispatch-time capability contract. The actual HTTP call and
model provider work remain outside Conversation locks. The original two
Rails-process crash cases continue in the final suite.

The earlier correction logs are `coordinator-ruby-final.txt`,
`coordinator-vue-final.txt`, `coordinator-rubocop-final.json`,
`coordinator-eslint.txt` and `coordinator-production-build.txt`. The final receipt
alias correction uses `receipt-alias-rspec.txt`, `receipt-alias-vitest.txt`,
`receipt-alias-rubocop.json` and `receipt-alias-eslint.txt`. The production build
slot was released when the successful build finished. Subsequent frontend edits
only strengthen the component test and its HTTP response fixture; the production
UI source has not changed since that build, so no repeat build was required.

The alias regression covers snake_case, camelCase, PascalCase, uppercase,
hyphens, dots, spaces, repeated separators, Unicode edge whitespace and a
Unicode letter that case-folds at a camelCase boundary. The API regression
initially failed on surviving client evidence; the actual frontend transform
and MessageMeta failed nine of the ten alias cases before correction. The
committed fixture was then regenerated from real corrected HTTP responses and
both regressions passed. Future API runs compare the same response contract.

## R13 boundary

This change handles outgoing booking notices only. Broader reservation overlap,
availability and rescheduling semantics, external calendar implementation, and
historical mutations remain R13 responsibilities. In particular, old applied
mutation entries without a notice Message ID are not automatically replayed:
R13 must reconcile provider/history evidence before repairing those entries.
No migration reinterprets historical provider IDs as local Message IDs.

## Acceptance still pending

The browser belongs to R06. No browser action, screen-lock retry or new unlock
request was made. R04 still needs desktop/phone Inbox inspection, reload evidence
and at least one real operator-created reply through the local Rails/fake provider
stack. Fixtures and component tests do not substitute for that proof. Issue #21
stays open and unintegrated, with integration owned solely by the coordinator.
