# Documents-First Knowledge Workspace

Status: Integration verification

## What to build

Create Knowledge as a Documents + Approved Answers + Needs Review workspace.
The completed slice must let admins manage general business documents, exact
approved claims, and review requests while enforcing the source-of-truth
hierarchy: Settings and Approved Answers control exact sensitive claims;
Documents provide general context.

## Reference screen

- Revised Documents-first Knowledge:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-b1c96520-7552-441c-bb87-ba0a100c6f61.png`

## Acceptance criteria

- [x] Knowledge top-level navigation opens a workspace with working Documents,
      Approved Answers, and Needs Review tabs.
- [x] Documents tab includes search, document list, selected document state,
      published/draft status, updated timestamp, overflow actions, editor,
      formatting toolbar, preview, publish changes, and revision history.
- [x] Import document and New document actions create tenant-scoped records and
      expose loading, validation, failed import, draft, published, archived, and
      no-documents states.
- [x] The right AI Employee access panel shows whether the document is used by
      WhatsApp AI Employee, which Offers it applies to, whether it can answer
      general questions, how sensitive topics route to Approved Answers, what
      happens when unsure, and Test this document.
- [x] Approved Answers tab manages exact approved claims for pricing, refunds,
      guarantees, eligibility, objections, policy, and other sensitive topics,
      including approval/rejection and version history.
- [x] Needs Review tab shows Review Requests, supports assignment, filtering,
      answer entry, send-to-Lead, propose as Approved Answer, reject, resolve,
      and linked conversation navigation.
- [x] Publishing a Document never authorizes exact sensitive claims unless a
      matching Approved Answer or Setting exists.
- [x] Conflicting Approved Answers or conflicting Settings are visible and route
      uncertainty to Review rather than AI Employee improvisation.
- [x] Visible labels use AI Employee vocabulary; if reference copy uses older
      assistant-access wording, implement it as AI Employee access unless a
      later product decision explicitly changes the glossary.
- [x] Every link, tab, form, filter, editor control, dropdown, toggle, and action
      introduced or touched by Knowledge is keyboard-reachable, has a visible
      state, and routes or persists through existing Rails/Vue conventions.
- [x] Realistic states include published documents, draft documents, saved
      changes, unsaved changes, rejected answer, pending approval, urgent Review,
      conflict warning, no search results, and failed save.
- [x] Rails request/model/service specs cover document CRUD, import, publish,
      approval, conflict precedence, Review Request resolution, tenant scoping,
      authorization, and AI retrieval eligibility.
- [x] Vue tests cover tabs, document list, editor state, toolbar controls,
      status dropdown, preview/publish, right-panel toggles, Approved Answers
      workflow, Needs Review workflow, validation, and error states.
- [x] Codex in-app browser checks cover creating a document, importing, editing,
      publishing, testing a document, Approved Answers conflict/details,
      resolving/rejecting a Review Request, linked conversation access, and
      mobile access through More.
- [x] A same-viewport screenshot at 1536 x 1024 is compared with the reference
      and documented as faithful within the visual tolerances; mobile behavior
      is checked at 852 x 1846 and 390 px widths.
- [x] `docs/issues/014/design-qa.md` exists with `Result: Passed`, screenshots,
      viewport dimensions, zero-overlap notes, and accepted deviations.

## Implementation notes

- Added tenant-scoped Knowledge Documents with draft, publish, archive, import,
  revision history, AI access flags, sensitive-topic controls, preview, and
  testing endpoints.
- Extended Approved Answers and Human Review Requests so Knowledge can surface
  conflicts, approve/reject/archive exact claims, resolve or reject reviews, and
  keep conversation links intact.
- Enforced retrieval precedence in backend services: Settings and Approved
  Answers control exact sensitive claims; Documents provide general context; no
  approved answer, uncertainty, or conflicts route to Needs Review.
- Browser QA passed using only the Codex in-app browser at the required
  desktop, intermediate mobile, and narrow mobile viewports.

## Blocked by

- Ticket 004: Unanswered-question review and knowledge approval.
- Ticket 010: Conversation Cockpit navigation and responsive shell.
