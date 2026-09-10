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

The corrected integration candidate is commit
`680609f94187b790243d33bf6eb38de439a1fc7f`, with tree
`7915e1d1585f340a13bc34834e2bac408ecbc040`. The normal commit hooks completed
before the final production build, so the build used that exact clean tree.

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

## Automated evidence

- Corrected frontend: 75 focused tests passed across the cockpit, reply-mode toggle and
  Conversation store actions.
- Corrected Rails: 28 focused authority examples passed. They cover control transitions,
  future-only resume, stale delayed-worker cancellation, opt-out persistence,
  public/private message handling, Review/Booking action priority, and
  authorized and rejected assignment with state preservation.
- Changed Ruby files passed RuboCop with no offenses.
- Changed frontend files passed ESLint with no errors. Five pre-existing style
  warnings remain in the cockpit template.
- Both English locale JSON files parsed successfully and `git diff --check`
  passed.
- The corrected production build transformed 5,078 modules and completed in
  1 minute 51 seconds with a 4 GiB Node heap. Its local log is
  `tmp/release-r07/build-corrected.log` (SHA-256
  `6814f62e42adf4eaf8e5be5f646fd2d6224a9f7ccb9014079bbcb29d05a74a2c`).
  The corrected `public/vite/.vite/manifest.json` SHA-256 is
  `adad158ba0e39edc896fa412fe1c71b100771f6b1ab2b80c2dce4941ff117d2e`.
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
