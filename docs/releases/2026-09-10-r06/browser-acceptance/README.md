# R06 browser acceptance and correction

Status: final acceptance in progress. The coordinator owns the browser for the
user's WhatsApp work. Phone modal and cleanup/re-invitation corrections have
passed focused tests and the production frontend build; final phone interaction
and successful re-invitation remain pending. Do not close issue #23 or treat this
evidence as launch approval. No real email, WhatsApp, AI or calendar delivery occurred.

## Observed source and fixture

Screenshots 01–08 were captured through the Codex in-app browser on the accepted
R06 tip `7161f8fef7902ed239f6d52c83f4661b1e533a96`, before the corrections below.
The focused correction is committed at
`75994e522336e1dd2aa8f2a04c269a42159ab0d4`; normal ESLint and Ruby commit hooks
passed, and the app/spec working tree was clean afterward. The source manifests
record the exact runtime and acceptance sources of this checkpoint.
JPEG signatures and dimensions were checked: desktop 1440×900, phone 390×844.
The preserved combined R04/R06 checkpoint `f33ca8aa14c07ccf3065831d37a5b7798ac185df`
was not edited or used as the source of these screenshots.

The isolated database is `ale_release_r06_browser`, with Rails on loopback 3216,
PostgreSQL 55486 and Redis 6396. Admin uses `localhost:3216`; member uses
`127.0.0.1:3216`, providing separate local browser sessions. Only these two local
origins are permitted by the disposable launcher's ActionCable configuration.
Production origin policy is unchanged. Mail is captured to local files; WebMock
blocks external requests; non-mail/socket jobs remain on the test adapter.

Cold development navigation took several minutes. The fixture now serves the
already verified production assets under `public/vite` using an ignored copy of
the guarded launcher, with `ViteRuby.reload_with(mode: 'production',
auto_build: false, public_output_dir: 'vite')`. No redundant build was run for
that switch. The corrected Team layout subsequently passed its allocated
production build: 5,078 modules in 8m14s with a 6GB Node heap after the default
heap exhausted. Those corrected assets now serve this fixture. The build slot
was released; the later backend media correction requires no additional build.

## Completed real UI observations

- Admin sign-in, Team invitation of `r06-neema@example.test`, captured local email
  acceptance and test password submission succeeded. Team changed from
  Verification Pending to Verified. Screenshot 01 is the pending invitation.
- The new member initially saw zero Conversations. The Admin Lead edit selector
  included her before any assignment, and assigned Asha's current inquiry #2.
- The member directory showed one Lead and only related Conversation #2. Asha's
  other inquiry #1 and the unrelated Baraka Lead were absent from the permitted
  Lead detail/list. The original fixture's “COLLEAGUE ONLY” text in #2 became
  permitted content after the deliberate Admin assignment.
- Member edit saved Business “Synthetic Dar Demo” and City “Dar es Salaam”;
  the edit dialog omitted Assignee. Import, Export, Knowledge and Settings were
  absent from the member's desktop navigation/workspace.
- The member added a synthetic reply, private note, text attachment and image
  through the composer. The image rendered at its actual 160×100 size.
  Screenshots 04–05 and the corresponding DOM evidence record permitted work.
- Admin reassigned inquiry #2 to Musa. The Admin screen confirmed Musa, but the
  already-open member view retained the old identity, list row and messages.
  Screenshot 06 is a failure, not accepted behavior. After explicit reload the
  member saw zero Conversations and “unavailable or you do not have access”
  (DOM evidence 07). Both sockets had confirmed subscriptions and other live
  events arrived, distinguishing this from a connection failure.
- Phone Team actions extended past the 390px viewport (the content scroller was
  465px wide). Horizontal scrolling could expose the controls and open Edit;
  screenshots 02 and 08 show why the initial layout is not accepted.
- A real local HTTP diagnostic subsequently confirmed why the old media tab did
  not make a new request: the protected image was sent with
  `Cache-Control: max-age=3155695200, public`. The intended after-action private
  header was applied after streaming had already committed the actual response.
  Existing integration response assertions did not detect that timing defect.

## Corrected browser checkpoint

Screenshots/DOM 09–14 use the corrected source and production assets. A fresh
member sign-in showed exactly one assigned inquiry. Direct links to Asha's other
inquiry #1 and Baraka's inquiry #3 showed the unavailable alert (09–10). Direct
Team settings and Business Account #2 navigation returned to the permitted
Business Account #1 dashboard (11–12); this was before adding any second-account
membership.

The member uploaded a new synthetic `r06-private-cache.png` after the cache fix.
It loaded at 160×100 and opened in the image viewer (13). This is a new blob;
the earlier publicly cached blob is not used as proof of the correction.

With the member's inquiry #2 open, Admin reassigned it to Musa through the Lead
edit dialog. Without any manual member refresh, the open view cleared and showed
the unavailable alert with All 0 and zero Conversations (14). The same new image
URL was then opened in a new in-app browser tab. The browser reported an HTTP
response failure, and Rails recorded a fresh GET at 07:41:04 +0300 followed by
`authorize_owned_blob` halting the request and `403 Forbidden`. The browser's
generated error page uses a data URL rejected by the tool's URL policy; that
page was not bypassed or treated as a screenshot of the product. The correlated
fresh request and denial, rather than an empty cached tab, establish this result.
The redacted server extract is `15-fresh-stale-image-server-denial.txt`; the
separate actual-wire header probe is `16-actual-wire-media-headers.json`.

## Correction and regression

The Lead update service reloaded its Conversation inside the outer transaction
after assignment. That cleared saved changes before the model's after-commit
assignment invalidation callback. Removing that reload preserves the existing
callback and transaction boundary. No authorization rules or event payloads are
changed. Team rows now wrap member details and place actions below them on phones.

The protected-media correction applies `private, no-store` before authorization
and overrides the proxy cache helper so streaming cannot commit a public policy,
including the original blob and representation helpers. The
separate WhatsApp provider capability and access checks remain unchanged.
The wire regression runs a local Puma listener against committed disposable spec
fixtures and reads the actual response headers before allowing the disk stream
to finish. It must run serially on a database ending `_spec` or `_test`; it
rejects the preserved browser database. The Net::HTTP adapter used by WebMock
buffers full responses, so it cannot alone verify this header timing boundary.
Rails request-test support also replaces Live threads with inline work; the
wire spec temporarily restores threaded streaming and restores the original
method afterward. The old code fails both blob and representation header checks;
the corrected code passes them and conditional/range access checks. A separate
probe of the actual browser server returns 200, `private, no-store`, and 314 bytes.

The combined correction suite passed 43 examples with zero failures. After a
test-helper naming cleanup, the final wire suite passed three examples again.
The five relevant frontend suites passed 37 tests. Ruby and Team Vue lint pass.

The regression uses the authorized HTTP Lead update and public socket event
boundaries specified by ADR 0010. Before the fix, the real request broadcast zero
access-change events to both affected operators (1 example, 1 failure). The fixed
request tests cover commit-only delivery to old/new operators, a combined
assignment/business/qualification edit, and rollback without notification or
changed HTTP access. The existing assignment audit expectation is also checked
against the already-established human-assignment action/control-state payload.

## Still required

- Complete independent coordinator re-review of the committed cleanup race correction.
- Direct hidden Lead and additional Admin-only settings denial through the browser
  while permitted assignment remains available; the hidden Conversation,
  cross-account and Team-settings cases above have passed.
- Final phone Lead Save hit-test and persisted values, then Escape cancellation.
- Successful browser re-invitation following revocation on the corrected runtime.

Session-end and account-revocation media denial, preservation of the other
account membership and identity, phone Team controls, and Inbox URL/back/focus
passed in the follow-on checkpoint below. Earlier blank/download tabs are not
used as evidence of denial.

The earlier Mac-lock/header-policy reports do not block current browser access.
Only the coordinator's shared browser allocation pauses the correction retest.

## Follow-on phone and membership checkpoint — correction in progress

The corrected phone Team rows fit the 390px viewport: document width is 390,
Edit spans x290–322 and Revoke spans x334–366 (17–18). The member's phone Inbox
contains one assigned inquiry, opens its query-backed Conversation URL, and
Back to list restores the row's keyboard focus (19–21). Phone Lead detail shows
only inquiry #2 (22).

A further phone failure was captured before correction: Lead edit Save sat at
y825–861 behind the mobile Bookings navigation link. The real click opened
Bookings without saving; the hit-test and screenshot are evidence 25. The
focused correction uses the existing CE Modal's stacking and scroll behavior,
retaining the Lead form and its permissions. A failing Escape-cancellation
regression supplements the actual browser layout regression; no CSS literal
assertion substitutes for the final phone click and saved-value check.

Admin added the existing Neema identity to the second synthetic Business Account
through Team invitation, then revoked her first-account access from the phone.
Both open member views cleared automatically and moved to the second account
with zero Conversations, preserving the same signed-in identity (23, 26–28).
The identical protected image URL made a fresh request after revocation and
returned 403 at 08:24:35 +0300. After access had been restored and the image
loaded again, UI logout returned to sign-in (30); the same URL made another
fresh request and returned 403 at 08:32:12 +0300.

Restoring the revoked membership exposed a second failure: the new AccountUser
committed, but the after-create callback attempted to insert notification
preferences already retained while deletion cleanup was pending. The unique
account/user constraint produced HTTP 500. The real revoke/reinvite HTTP
regression reproduces that response. The focused correction reuses an existing
notification setting for the same user and account, applies defaults only to a
new setting, and leaves another account's preferences untouched. The final test
also runs the pending deletion job after restoration. Browser re-invitation must
be repeated successfully before this path is accepted.

Coordinator review of `1907f72c312ffc22efbec9afd7caf1a0a739e981`
found no Standards issues and one cleanup race: checking for restored membership
before taking a lock allowed a stale cleanup job to delete preferences after
re-invitation succeeded. Correction
`323d381291a51ae573e0f840cec12dab2d0784bc` holds the same Account row lock
as AgentBuilder across the membership recheck and all cleanup. Separate database
connections and bounded PostgreSQL row-lock barriers reproduce both orderings
without mocking job internals. Before the correction, both cases failed: cleanup
first left a successful re-invitation with settings returning 500; invitation
queued first lost retained preferences. After correction, all 19 membership
examples pass, including unchanged preferences and assigned Conversation access
in the other Business Account. Both Ruby files pass lint and normal commit hooks.
This spec must run serially on the disposable `_spec` or `_test` database.

The final phone-modal production build passed on the exact `1907f72` frontend
inputs: 5,078 modules in 16m33s. The build slot is released. The subsequent
cleanup fix changes only Ruby and does not require another frontend build.
Exact input and manifest hashes, test counts and pending browser checks are in
`follow-on-checks.json`. Final phone Save/Escape and successful re-invitation
remain pending a browser grant; no pending check is marked accepted.
