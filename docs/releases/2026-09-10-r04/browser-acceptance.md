# R04 corrected desktop and phone acceptance

The coordinator-allocated in-app browser walkthrough passed on 10 September
2026 against implementation `3ade7aa34cc863ba2043e4a90f4bca79291abdbc`
and documentation tip `a0f9f7c5c501f50070feb8dd4df35ce0dee997ae`.
The actual page loaded `dashboard-CBAPqSQd.js`. No runtime source changed and
no previously passed test suite or production build was rerun.

Only R04's synthetic localhost account was used: Rails 3224, provider 3225,
Account 1, Conversation 1. The guarded test runtime kept all external HTTP
blocked, delivery queues held and live launch approval absent. The operator
created replies and used Retry through the real Inbox; the held SendReplyJob
then executed through the real sender against the loopback provider. Later
provider failure used the existing MessageStatusProjector helper. No Meta,
stage, WhatsApp Web or R06 tab was touched. The browser slot has been released
to the coordinator; fixture and service state remain preserved.

## Observed path

At **1440×1000**, the operator created Message 9. A captured temporary echo-ID
row reconciled into one saved Pending row, then changed live to “Accepted by
WhatsApp; awaiting delivery” after exactly one provider request. There was no
reload between Pending and acceptance, no false Sent label and no duplicate row.

Message 10 was created through the Inbox and definitely rejected by the local
provider. It changed live to Failed to send and exposed Retry. Clicking that
actual control returned the same Message ID to Pending. Its explicit retry
made one further request and remained failed because the synthetic provider
deliberately rejects that content. This was the only reply sent twice, once
initially and once by the explicit operator retry.

Message 11 changed live from Pending to Delivery unknown, with no retry control
and one durable Review Request. Three more sender jobs made no provider request
and left that review count at one. Desktop reload preserved accepted, failed
and unknown outcomes.

At **390×844**, the operator created Message 12 through the phone composer. It
reconciled into one saved Pending row and changed live to accepted/awaiting
delivery after one provider request. Message 13, also created at phone width,
changed live to Delivery unknown with no retry and one review. Repeated jobs
for the accepted Message 12 and unknown Message 13 made no additional request.

A later synthetic provider failure on Message 12 changed the live phone Inbox
to Delivery failed while retaining its accepted provider identity. No generic
retry appeared. Phone reload preserved this failure and Message 13's unknown
outcome. Returning to desktop showed the same outcomes and three open reviews:
the original fixture review plus one each for Messages 11 and 13.

The same-minute fixture Unknown label remained visible before an accepted reply.
Canceled and Pending fixture labels were also inspected at phone width. The
composer, delivery labels and applicable Retry controls fit the phone viewport;
all captured document widths matched their viewport widths.

## Evidence and bounds

The [verification record](browser-acceptance/verification.json) checks all
17 browser snapshots and 10 real sender/projector records. Every captured row
ID is unique, and no fresh reply text appears twice. Final storage contains
13 Messages. Provider history grew from 5 to 11 requests: one for each of the
five fresh replies, plus the one explicit retry. Each new unknown reply has
exactly one Review Request. The launch gate remained unapproved throughout.

Screenshots are original JPEG bytes from the in-app browser. Each has a matching
DOM text snapshot and a JSON record of the viewport, loaded build, Message IDs,
visible delivery labels and retry controls. `desktop-fresh-optimistic` records
the temporary row; `desktop-fresh-pending` records the later persisted ID.

- [Desktop live acceptance](browser-acceptance/desktop-live-accepted.jpg)
- [Actual retry returning to Pending](browser-acceptance/desktop-retry-pending.jpg)
- [Phone live acceptance](browser-acceptance/phone-live-accepted.jpg)
- [Previously hidden grouped Unknown label](browser-acceptance/phone-grouped-unknown.jpg)
- [Phone live provider failure](browser-acceptance/phone-live-later-failure.jpg)
- [Phone outcomes after reload](browser-acceptance/phone-reloaded-outcomes.jpg)
- [Final desktop outcomes and review count](browser-acceptance/desktop-final-outcomes.jpg)

This walkthrough verifies ordinary live creation/update reconciliation and
single-row rendering on the actual app. The deliberately delayed serialized
creation-job ordering remains covered by the canonical API-to-store/list
regression in [creation ordering corrections](created-order-corrections.md).
Browser evidence does not replace the existing competing-worker, process-crash
or signed-receipt regression evidence, and the loopback provider does not prove
a real Meta launch. No new code defect was found. Integration and issue closure
remain the coordinator's responsibility.
