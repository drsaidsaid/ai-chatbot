# R06 — Assigned Team Member access

Status: implementation, automated checks and local browser acceptance passed.
Real browser findings in reassignment invalidation, phone controls, streamed
media caching and re-invitation are corrected. Final phone Save/Escape/persistence,
successful revoke/reinvite and hidden Lead/Admin-only direct links pass on runtime
`323d381291a51ae573e0f840cec12dab2d0784bc`. Both independent coordinator
re-reviews have zero findings. The browser and build slots are released.
Issue #23 remains open for coordinator review and integration. This is not a
production launch approval.

A subsequent combined review found a deadlock between membership cleanup and
operator-review creation. The backend correction at
`dd49ef996b1b9e0cb1f9e5c9b356bf781e06b21f` changes cleanup's Account lock
strength and passes all 20 focused membership examples, including a real
two-connection deadlock regression and both re-invitation orderings. See
[combined lock correction](combined-lock-correction/README.md) for the preserved
red proof and final green result. Independent Standards and Spec reviews of
this later correction both have zero findings. The accepted browser evidence
and fixture are unchanged.

## Source and decision

- Branch: `codex/r06-assigned-access-20260910`.
- Main implementation commit: `461c1405b2a6d64ac3da2b4e7416b49efaf93f78`.
- Original integrated R01/R02 base: `5577a37ddae5f6d08b33b0b33aefe6d933d7003c`.
- Accepted R03 predecessor: `f2b184e1c332f0bf68c31dec460f7e5599657a72`.
- Combined refresh: [merge and verification evidence](integration-refresh/README.md).
- Decision: [ADR 0010](../../adr/0010-assigned-conversation-access.md).
- The pinned CE version, MIT notice, lockfiles and frozen audit files are unchanged.
  R06 adds no schema changes; the refresh inherits R03's accepted schema and
  migrations unchanged.
- R03 owns WhatsApp health authorization/redaction. R04 owns final-send gates.

Admin and Team Member map to the existing CE roles. Membership and current
assignment are checked on HTTP reads/writes, search/filter counts, related Lead
evidence/reviews/bookings, exports, media, queued notifications and socket delivery.
Shared Inbox/team/participant membership grants no extra Conversation access.
A member can edit the identity of a Lead with assigned work; conversation evidence
remains scoped, and combined Qualification/booking preparation is withheld when
another Conversation for that Lead is inaccessible. Stored AI evaluations remain
unchanged for display.

The Team screen offers two roles and the existing invitation flow. Admin Lead
editing lists every current account member, including a new member with no prior
assignment; revocation removes that member from the selector. Expired,
replayed and revoked invitations are rejected. Account revocation preserves the
User and other Business Account memberships. Members cannot reassign work,
import/export Leads, approve Knowledge or manage business/provider settings.

Native media reads use an encrypted HttpOnly cookie tied to the original CE
session. Every proxy, representation and legacy disk/blob read resolves current
assignment again. Dashboard sockets also require that live session and drop
content after reassignment/revocation. Content-free access changes clear open
views; dashboard events omit contact widget socket credentials.
WhatsApp sends use a separate five-minute, purpose-bound attachment capability;
it streams only an eligible public outgoing WhatsApp attachment, with Rails'
normal safe content types. It is never returned as a dashboard attachment URL.

## Automated evidence

Before the R03 refresh, the combined R06 Rails run passed **186 examples, 0 failures**. It includes the R06
request/job/session scenarios, R02 Inbox rows and batched message previews,
Leads, search, policies, booking/team controllers, native attachments, unread
counts, bulk work and realtime listeners. A separate final media run passed **5 examples, 0 failures**, including a real
image thumbnail response and stale current/legacy URL denial after reassignment.
The local test needed native `vips` installed; no application workaround was used.

A final first-assignment regression initially failed because the new member was
missing from the Admin selector. After correcting its account-members query, the
focused request and Lead regression run passed **15 examples, 0 failures**, with
clean lint on both affected Ruby files. This backend-only follow-up leaves the
validated frontend build inputs unchanged.

The Vue suites passed **29 tests**, and the R02 navigation suite passed **8 tests**.
They cover fixed-role invitation submission, member editing without reassignment
or import/export controls, access invalidation reload, cockpit selection and
five-destination navigation. Frontend lint has no errors; five pre-existing
cockpit formatting/i18n warnings remain.

The pre-refresh production Vite build passed: **5,078 modules, 2m35s**.
The combined R03/R06 build passed: **5,078 modules, 3m36s**.
Ruby lint passed across 79 changed/new files with no offenses. Whitespace checks
passed. Exact commands and results are recorded in `checks.txt`.

## Alternative-path review fixes

The coordinator's three confirmed access gaps are fixed. V1 macro HTTP endpoints
return 404 for both roles without queueing work. Legacy macro jobs resolve current
Conversation access and require current Admin membership plus macro visibility
before execution; a member's personal macro cannot self-assign hidden work, send
messages or queue a disclosure webhook. Lead merges require the existing Admin
destructive-operation policy before either contact is resolved. Contact bulk labels
resolve the actor's current visible contacts in the execution service, and queued
bulk deletion requires current Admin membership.

The review regression passed **79 examples, 0 failures**, covering the new paths
and the existing R06 invitation/media/realtime paths. Cases include reassignment,
queued demotion/revocation, current Admin positive paths and cross-account IDs.
All 11 changed/new Ruby files passed lint. The changes are backend-only; no
frontend build inputs changed. The upstream macro implementation is retained;
its HTTP specs now assert the V1 unavailable contract, while the legacy executor
service tests still run. See `review-follow-up.md` for the red/green evidence.

## Browser evidence — accepted locally

The earlier Mac-lock report is obsolete. On 10 September the in-app browser
completed Admin sign-in, invitation, local email acceptance, member Lead editing,
assigned replies, private notes and image rendering. The member directory and
related Conversation list were scoped to assigned work.

The real Admin Lead reassignment path left an old member view visible. Fresh
Conversation reads correctly denied access. A separate phone check found Team
actions offscreen by default, though horizontal scrolling could reach them.
An actual HTTP probe also found public media headers committed before the
after-action. The corrections pass 43 Ruby examples, 37 frontend tests, lint and
the Team layout production build. In the corrected browser, reassignment clears
the member view automatically and the same newly uploaded image URL makes a
fresh request that returns 403. Phone Team controls and Inbox back/focus pass;
revocation automatically clears the account view while preserving the other
Business Account and identity. Fresh requests to the same image return 403 after
revocation and logout. Final phone Lead Save/Escape and successful re-invitation
pass. Their focused corrections pass 16 frontend tests, 19 membership
examples, lint and the 5,078-module production build. The membership tests include
real concurrent cleanup and invitation in both orderings.
See [browser evidence and correction](browser-acceptance/README.md) for exact
provenance, screenshots, completed cases and regression evidence. Issue #23 remains
open until coordinator integration. Final browser evidence and source hashes
record the accepted browser checkpoint; the later backend lock-strength
correction is documented separately above.

## Isolated reproduction

The accepted browser fixture is preserved and its Rails process has been stopped
to release memory. Use [resume instructions](fixture-resume.md) for that existing
fixture; the fresh-database instructions below are for a new disposable setup.

Use the R01 documented runtime and a disposable PostgreSQL database. R06 used
PostgreSQL port 55486, Redis 6396, Rails 3216 and Vite 3096. The spec database is
`ale_release_r06_spec`; the browser database is `ale_release_r06_browser`.
No real customer, WhatsApp, AI or calendar credentials are loaded.

Set `RAILS_ENV=test`, the isolated PostgreSQL/Redis variables, `FRONTEND_URL` to
`http://127.0.0.1:3216`, `VITE_RUBY_HOST=127.0.0.1`, `VITE_RUBY_PORT=3096`,
`SMTP_ADDRESS=127.0.0.1`, a local sender address and a synthetic
`RELEASE_ADMIN_PASSWORD`. Keep secrets outside Git. Install native `vips` for
real thumbnail rendering; the production Dockerfile already installs it.

Load the current schema into an empty disposable database (or apply R03's
accepted migrations to the existing isolated fixture), then run
`bundle exec rails runner script/release/r06_seed_synthetic.rb` against the
browser database. The script refuses other databases and refuses existing
accounts through the baseline seed guard. Start the browser fixture using
`bundle exec rails runner script/release/r06_browser_server.rb` and
`pnpm exec vite --mode test`. The launcher blocks external network access,
captures email under `tmp/release/mail`, executes only mail/socket jobs inline
and keeps other jobs on the test adapter. It binds Rails to loopback port3216.

Synthetic users: `release-operator@example.test` (Admin),
`r06-colleague@example.test` (Team Member). Invite a third synthetic member from
the UI. The fixture contains two Business Accounts, two inquiries for Asha,
a separate Baraka Lead and an attached text file. No actual invitation email or
provider send leaves this local environment.
