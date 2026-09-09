# R02 — simplified navigation and the first complete Inbox path

9 September 2026 · Local acceptance complete; awaiting coordinator integration.

Branch: `codex/r02-navigation-20260909`, based exactly on the coordinator-reviewed
R01 integration `fb7d54ac3c527940a63b171c45e4e2e7ca898d26`. No integration worktree,
donor checkout, frozen audit evidence, dependency lockfile, schema or MIT license
was edited. GitHub #19 remains open for coordinator review and integration.

## Delivered behavior

The owned CE dashboard uses Inbox, Leads, Bookings, Knowledge and Settings.
Phones use Inbox, Leads, Bookings and More; permitted Knowledge and Settings
destinations are in More. Administrators reach the full Test Center through
Settings → AI & testing. Its old URL redirects with query and fragment intact.
Settings keeps a desktop navigation rail or a named phone selector around all
supported native and owned pages, including teams, inboxes and AI provider setup.
The login and application share the AI Lead Employee identity. Owned logo URLs
include a content fingerprint so browsers replace cached CE logos on upgrade.

Inbox now queries Conversations through an account- and policy-scoped endpoint.
A Lead without Qualification remains visible, and two inquiries from one Lead
remain two selectable Conversations. All is the default; Needs review counts
Conversations with open requests and Hot leads counts Conversations for highly
qualified Leads. Search, optional qualification/assignee/source filters, actual
confirmed Booking and pending-due Follow-up filters, counts and pagination use
that same permitted scope. Operator-alert Conversations are excluded. Private
notes and activity messages are excluded from message search and row previews.

Selection, queue and filters live in the route. Opening, refreshing and returning
to a Conversation preserves the list, and Back to list restores focus to its row.
The list remains selectable at normal in-app, phone and desktop widths. Errors
offer a retry or a return to the list. The Conversation heading separates the
Lead name, phone, control state and assignee so they remain readable.

Customer questions needing review live in Inbox; Knowledge presents its existing
draft/approval lifecycle without requesting customer-review records on load.
Standalone Knowledge defaults and English/Swahili greeting fallbacks no longer
advertise Online Profits. V1 navigation
gates retained unsupported CE routes; the server also rejects non-Meta-Cloud
channel creation and returns 404 for public widget/help-center/survey surfaces.
The CE implementation remains in source and no enterprise source was introduced.

## Evidence

The [visual reference](visual-reference.md) was prepared before layout expansion.
It uses the approved audit's CE layout and establishes spacing, type, touch
targets and visible focus for desktop and phone.

Final [browser observations](browser-observations.json),
[screenshots](screenshots/07-desktop-conversation.png) and
[verification results](checks.json) are recorded alongside this file.
All browser work uses this task's in-app browser tab,
production-built frontend assets, an isolated test Rails application and purely
synthetic records. It creates no provider connection or live delivery.

- **26 Ruby examples pass:** the new Conversation query and V1 gates, the
  existing Conversation policy and baseline sign-in/recovery/account checks.
  Six additional English/Swahili intent-classifier examples pass; 32 Ruby examples
  pass in total.
- **41 Vue tests pass across seven suites:** navigation, phone shell, Inbox,
  persistent Settings, Knowledge, route guards and Dashboard. The last focused
  Inbox run adds and proves restored keyboard focus with a slow request boundary.
- Changed Ruby files and SCSS pass lint. ESLint reports zero errors and 58
  warnings, mainly inherited Vue formatting conflicts and dynamic i18n keys.
- Production Vite build passes: 5,078 modules, 1m 46s. Existing Browserslist age,
  large-chunk and the package's missing development source-map warnings remain.
- Final in-app paths run at 390×844, 1280×720 and 1440×900 without document-wide
  horizontal overflow. Search plus an Unknown quality filter survives navigation;
  a returned row has a visible 2px outline and can reopen with Enter.
- Administrator Settings, old Test Center direct links with query/hash, refresh,
  browser back and member denial are verified. All six phone Settings groups
  remain reachable, including actual native provider and WhatsApp forms.
- All **155 frozen audit/approved-plan files**, both dependency lockfiles, the
  schema and MIT license remain byte-identical to the R01 integration.

The browser caught two issues that tests alone had missed: list refetching removed
the row before focus restoration, and immutable asset caching retained the old
login logo. Focus and logo-version regressions now fail before their fixes and
pass afterward. Earlier development-only navigation/HMR errors are recorded
separately; the final packaged navigation path adds no browser console errors.

## Local reproduction

Follow the [R01 runbook](../2026-09-09-r01/runbook.md) using this branch and its
locked dependencies. R02 used Rails 3212, Vite 3092 during development,
PostgreSQL 55482, Redis 6392, browser database `ale_release_r02_browser` and test
database `ale_release_r02_spec`. The private environment, service data and full
check logs stay under ignored `tmp/release*` paths in this worktree. No worker
consumes queues. Browser Rails uses `RAILS_ENV=test` and the production Vite
output with `VITE_RUBY_PUBLIC_OUTPUT_DIR=vite VITE_RUBY_AUTO_BUILD=false`.

Start with `script/release/seed_synthetic.rb` on an empty disposable database.
The browser fixture extends it to two Leads and three paused Conversations:
Grace Mrema has two incoming inquiries and no Qualification; Amina Kileo has one
incoming question, a highly-qualified Qualification and one open human-review
request. An Agent-role synthetic member belongs to the fixture Inbox. No Booking,
AI provider, WhatsApp channel or calendar is configured. Request specs separately
prove real Booking and due Follow-up filters, inaccessible records and pagination.

## Successor handoff and limits

- **R06:** `ConversationPolicy::Scope` is the common entry point used by the new
  `inbox_conversations` endpoint before row selection, counts, filter options and
  search. It deliberately mirrors the existing `show?` policy: administrators
  see the account and members see their inbox/team membership. Implement the
  approved assigned-conversation restriction consistently in both policies and
  other search/export endpoints; R02 does not claim R06's stronger isolation.
- **R07:** `InboxConversationCockpit.vue` now owns Conversation-based list routing,
  narrow-screen list/detail visibility, restored row focus and request-race/error
  handling. Preserve these tests when changing control actions. R02 suppresses
  inherited booking fields unless the next action is `confirm_booking` and an
  actual Booking exists; it also removes the invented tomorrow fallback. The
  wider next-action/control correction remains R07.
- **R03/R04:** V1 channel creation allows `whatsapp` with `whatsapp_cloud`; the
  retained WhatsApp route renders the CE CloudWhatsApp form. The outer Settings
  selector must remain when onboarding/health flows change. API-only local
  fixtures are test plumbing, not a supported production setup option.
- **R10/R11/R12:** Provider setup and Test Center retain their administrator gate.
  Knowledge's Drafts & approvals tab uses existing answer status controls; this
  ticket does not certify import quality, retrieval or review lifecycle rules.
- **R13/R14:** Booking hours, Follow-ups, Team & alerts and native Inbox settings
  are reachable in the persistent Settings layout. Their deeper behavior and
  real calendar/WhatsApp/alert delivery remain the owning tickets' acceptance.
- **R18:** The build and browser evidence use synthetic local services. They do
  not establish deployment, deliverability, provider credentials or launch approval.

Task-owned Rails, Vite, PostgreSQL and Redis services are stopped after verification.
The normal installed pre-commit hooks ran without bypass. The containing commit
is available with `git log -1 --format=%H -- docs/releases/2026-09-09-r02/README.md`.
