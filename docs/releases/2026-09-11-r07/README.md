# R07 Conversation control evidence

## Candidate

The first implementation candidate was commit `a601919` on
`codex/r07-conversation-control-20260910`, based on integrated predecessor
`f6e111b46c65e17711b93c1cb3f81fb5d8b12450`.

- First-candidate tree: `d2de65faf30899e2973b8ce84c2714456a6c749e`
- `pnpm-lock.yaml` SHA-256:
  `9aff591bedb980ca3d5d1c9efe23b6b85eaefc28b47cdaf4e55f9e95fea04691`

Independent review found gaps after that build. The corrected source rejects
resume from Handoff Requested under the row lock, preserves ownership and
pending work on rejection, prioritizes an open Review Request over booking
history, treats only a currently confirmed Booking as read-only “Call booked”
information, and lets an administrator choose an actual operator while hiding
assignment controls from Team Members.

A subsequent concurrency review found that public takeover and resolution wrote
Inbox status before acquiring the control lock, pause accepted a closed
Conversation, and an action completing after navigation could replace the newly
selected Conversation with the prior result. The final source performs the full
takeover/resolution transition under the actor-aware Conversation lock, rejects
control changes for any resolved Conversation, and binds every cockpit action
result to the account and Conversation on which it started. It also exposes the
existing AI handoff controller action through its missing public route, permits
handoff only from AI Active, and dispatches bot handoff only after the atomic
transition commits. Both control surfaces disable Resume during Handoff Requested
and explain the required takeover or assignment.
Pending and snoozed status changes now use the same actor-aware lock. A delayed
store response cannot mutate a same-display-ID Conversation in another account,
and bot handoff records a uniquely keyed durable Outbox Event in the transition
transaction. Failed and duplicate jobs retry without repeating the transition or
delivering duplicate handoff effects. Each asynchronous notification and
reporting consumer claims a database-enforced receipt before applying its
effect, so a worker crash after dispatch can safely replay the Outbox Event. The
scheduled outbox recovery batch also picks up a committed handoff whose original
job enqueue was interrupted. A rejected asynchronous enqueue leaves the event
pending for that recovery batch instead of falsely marking it delivered.

The prior corrected integration candidate was commit
`680609f94187b790243d33bf6eb38de439a1fc7f`, with tree
`7915e1d1585f340a13bc34834e2bac408ecbc040`. The final independently reviewed
source is commit `89d96dadb660ae35600cd4bbe64c595aa9debe8f`, with tree
`c2aef6014239449b4e0cbb73a3c5034f089a14a5`. The staged tree before normal
commit hooks had the same identity, so the production build used the exact
reviewed source.

The Conversation cockpit keeps identity, phone, control and assignee visible;
shows review and booking actions only when their records exist; persists takeover,
assignment, pause, explicit resume and resolution; reports success and failure;
and explains why controls are unavailable after resolution. The reply mode toggle
names the public Reply and internal Private Note boundary for keyboard users.

Explicit resume clears the Human Operator assignment and increments the control
version. It does not create a Message, revive a blocked intent or alter automated
contact consent. Only a later eligible inbound Lead Message can record new work.

## Red evidence

The new regressions were run against the first candidate before the corrected
implementation was restored byte-for-byte. Five of six focused Rails examples
failed: Handoff Requested resumed successfully through both the service and
public API; Booking outranked Review; confirmed Booking was presented as a new
confirmation action; and historical Booking records were recommended. The
existing unauthorized-assignment authority check passed. The prior cockpit
failed four of 18 examples covering read-only confirmed Booking, unavailable
handoff resume, administrator operator selection, and failed reassignment.
A separate stale-assignee regression failed against the prior service because
it did not accept or recheck the acting operator; the corrected service checks
current access inside the same row lock as the transition.

Logs are retained locally at `tmp/release-r07/red-rails.log` and
`tmp/release-r07/red-frontend.log`.

The later concurrency regressions were also proven red against immutable commit
`2c62fbc`: all four focused backend examples and all four focused cockpit examples
failed. Those logs are retained at `tmp/release-r07/red-final-backend.log` and
`tmp/release-r07/red-final-frontend.log`.

## Automated evidence

- Corrected frontend: 75 focused tests passed across the cockpit, reply-mode toggle and
  Conversation store actions.
- Final frontend regression run: 89 focused tests passed, including route changes
  during assignment, pause, takeover and resolution requests, same-display-ID
  account changes, feedback clearing and the secondary AI control panel.
- Final public control run: 37 focused examples passed, including stale-assignee
  takeover/resolution rejection, resolved-state cross-product rejection, atomic
  bot handoff failure preservation, consumer receipt rollback/replay and the
  routed AI handoff.
- Final combined R07 backend run: 41 examples passed after adding scheduled
  recovery for a lost immediate enqueue and pending retry for an explicitly
  rejected asynchronous enqueue.
- Final authority integration run: 18 examples passed across control access,
  orchestration, consent, outbound delivery and assigned-resource boundaries.
- Corrected Rails: 28 focused authority examples passed. They cover control transitions,
  future-only resume, stale delayed-worker cancellation, opt-out persistence,
  public/private message handling, Review/Booking action priority, and
  authorized and rejected assignment with state preservation.
- Changed Ruby files passed RuboCop with no offenses.
- Changed frontend files passed ESLint with no errors. Five pre-existing style
  warnings remain in the cockpit template.
- Both English locale JSON files parsed successfully and `git diff --check`
  passed.
- The prior corrected-candidate production build transformed 5,078 modules and completed in
  1 minute 51 seconds with a 4 GiB Node heap. Its local log is
  `tmp/release-r07/build-corrected.log` (SHA-256
  `6814f62e42adf4eaf8e5be5f646fd2d6224a9f7ccb9014079bbcb29d05a74a2c`).
  The corrected `public/vite/.vite/manifest.json` SHA-256 is
  `adad158ba0e39edc896fa412fe1c71b100771f6b1ab2b80c2dce4941ff117d2e`.
- The final independently reviewed production build transformed 5,078 modules
  and completed in 2 minutes 59 seconds with a 4 GiB Node heap. Its local log is
  `tmp/release-r07/build-final.log` (SHA-256
  `088c1051e8b231e0441f54fe8ac874dfc30190f8820c6bbbe909375aa178c3e4`).
The final `public/vite/.vite/manifest.json` SHA-256 is
  `f051781f2afd3383cb4fe12c3b5f8c0cbdbc4783b6a0b09c38f9241b60f65a91`.

## Post-commit review follow-up

Integration review after evidence commit `c47f771` found two further bounded
public-control cases. The prepared follow-up passes the authenticated Agent Bot
into the locked service transition and rechecks that it remains accessible,
actively associated with the Conversation Inbox and the exact assigned bot. It
also dispatches recovery with the Outbox Event creation time so reporting does
not treat a delayed recovery as the handoff occurrence time.

The immutable follow-up source is commit
`54c8713f4be95cab718cc9e13b2c9f2f0a261b45`, with tree
`083cd69ecbf50e75ff5b3324f601a0d7d5501592`. The staged tree before normal
commit hooks had the same identity, so the hooks did not alter the reviewed and
tested source.

Public regressions cover an unrelated Inbox bot and reassignment between the
controller guard and service lock, preserving status, Control State, control
version, assignment, pending intent and outbox absence on rejection. The
recovery regression covers original occurrence time and repeated recovery
idempotency.

All three regressions failed for their intended reasons against immutable
evidence commit `c47f771`: both unauthorized bot requests returned HTTP 200, and
the delayed recovery dispatched with the recovery time two hours after the
Outbox Event. The log is `tmp/release-r07/red-post-c47.log` (SHA-256
`9c8122a822a066264c25c35d3da8d8c6db4f562bb8f6144a9de0953baf6278b0`).

With the follow-up restored, 7 focused public authorization, recovery, reporting
and consumer-receipt examples passed. A further 15 existing control-service,
handoff-job and receipt examples passed. The logs are
`tmp/release-r07/green-post-c47.log` (SHA-256
`9bb3aeb345eca6ef5f965a3bf60faa37e576ed0fa975e937820f858c50b947c7`)
and `tmp/release-r07/green-post-c47-preservation.log` (SHA-256
`abf1de2cd1ebd6c4aa33ced3dc22d33d531b700f03856be6b78298530d7b9d58`).
All changed Ruby files pass RuboCop and `git diff --check` is clean. Frontend
bytes are unchanged from source commit `89d96da`, so its verified 89 tests and
production build remain the applicable UI evidence; no additional UI build is
required for this backend-only follow-up.
- The first-candidate production Vite build transformed 5,078 modules with a 4 GiB Node heap.
  Its full output is preserved locally at `tmp/release-r07/build.log` (SHA-256
  `91ae2187086ad698b7a045b11b0ab198ba1a1bde80a8ade94ddca9a69f5ad27b`).
  The generated manifest SHA-256 is
  `392b1189ef7a2abdbbc6cafb3839b456600217d637bfe66bd33785c08adfa016`.

## Isolated browser fixture

The prepared fixture uses only synthetic records and no WhatsApp, AI or calendar
connection. External HTTP is blocked by WebMock. It uses:

- Rails `127.0.0.1:3227`
- PostgreSQL `127.0.0.1:55527`, database `ale_r07_browser_test`
- Redis `127.0.0.1:6427`
- Admin `release-operator@example.test`
- Team Member `r07-member@example.test`
- an assigned AI Active review Conversation with a pending stale intent and
  withdrawn automated-contact consent
- an actual confirmed booking Conversation
- a resolved Conversation with unavailable controls

The untracked fixture, generated secrets, database and logs are retained under
`tmp/release-r07`. Its guarded server explicitly reloads Vite Ruby in production
mode so the test Rails environment serves the built assets. To resume after
browser access returns, start only the retained R07 PostgreSQL and Redis
instances, load `tmp/release-r07/runtime.env`, and run:

```sh
VITE_RUBY_PUBLIC_OUTPUT_DIR=vite VITE_RUBY_AUTO_BUILD=false \
  bundle exec rails runner tmp/release-r07/server.rb
```

Open `http://127.0.0.1:3227/app/login` in a dedicated in-app browser tab. The
synthetic password remains only in the untracked environment file.

## Pending browser acceptance

The runtime returned HTTP 200 and exclusively owned its assigned ports. The first
in-app browser navigation timed out. A coordinator reproduction then returned:
`The Mac is locked and automatic unlock could not unlock it`, followed by a
request-header policy loading error. No browser acceptance is inferred from the
healthy runtime or build, and no screenshots were captured.

The first launcher also attempted to reach the test Vite development endpoint.
Before shutdown, its retained definition was corrected to use
`ViteRuby.reload_with(mode: 'production', auto_build: false,
public_output_dir: 'vite')`. That launcher correction still requires a healthy
restart in the next allocated interval.

After a normal Mac unlock and a fresh allocation, validate the corrected source
on the real desktop and 390x844 flows: readable
identity and ownership, review without booking fields, actual booking details,
takeover and stale-intent cancellation, pause, resume clearing assignment while
consent stays withdrawn, assignment, resolution, unavailable-state explanation,
public/private mode distinction and keyboard operation. Record persisted database
state after each control action.
