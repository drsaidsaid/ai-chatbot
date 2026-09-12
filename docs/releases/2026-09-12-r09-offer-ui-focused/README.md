# R09 Offer UI — focused development checkpoint

This is a reviewable UI development checkpoint, not full R09 acceptance.

## Source and evidence

- Accepted delivery increment 2 checkpoint: `1ede019dfa15f62b6d2ac3da4ffb106f642ac42d`.
- Initial frozen UI source: `e7a01adee5225edf100329c36afb6379b719cc20`, `refs/r09/offer-ui-focused-source-20260912`.
- Final checked UI source: `e82a6c0c200e0dc9d2dc8c8de0e58a7a9b199648`, `refs/r09/offer-ui-checked-source-20260912`.
- Evidence ref: `refs/r09/offer-ui-focused-evidence-20260912`. The handoff supplies its immutable tree SHA. Its delta from final source is exclusively this release directory.

## Implemented path

The existing Offers and qualification settings tab now uses the per-Offer API.
Owners can create/edit an Offer, its labeled currency amounts, typed questions,
enabled/required states, order, ranges, bounded typed rules and score thresholds.
Saving retains revision authority and exact major-unit decimal strings. A 409
keeps the draft until explicit reload. Question display respects saved positions;
removal/addition normalizes ordering without changing field identities.

Leads selection/filter/export requests preserve explicit Offer scope. Shared
identity edits omit legacy evidence when Offers exist. A full scoped evidence
reader shows the Offer, evaluated/current revisions, stale/legacy state,
negative/unknown/superseded observations and authorized source links. Both the
reader and directory ignore obsolete responses; a new Offer selection clears
previous qualification presentation while loading.

The Conversation component adds explicit Offer selection and scoped human
correction requests. Existing qualification outcome/follow-up/handoff displays
remain. Legacy evidence inputs are hidden for Offer-scoped qualification, and
stale next questions are not recommended. The original control-panel script is
byte-identical except for the additive component import; `r07-isolation.json`
records this check and the shared files for root integration review. R07's
reviewed candidate was inspected read-only and not imported. Provider settings,
shell/navigation, R06 access and filter/export boundaries are retained. No
campaign routing or R11 work was added.

## Verification

- Final frozen source: **43 Vue tests passed**, 9 files. Includes new settings,
  scope, evidence and response-race cases plus existing control-panel, owned
  layout, provider-settings and navigation suites.
- Final frozen source: **29 Rails examples passed**, 0 pending. Scoped-reader,
  directory-filter and Offer-selection suites include representative canonical
  incoming-message qualification and R06 visibility restrictions.
- Each run independently verified exact whole-tree equality before and after.
  See `ui-checked-verification.json`, per-run `*-before.json`/`*-after.json`,
  `ui-checked-*-invocation.json`, results JSON and corresponding `*-log.txt`.
- The earlier UI source ran **42 Vue / 29 Rails**, also with whole-tree equality.
  It predates the final saved-question-order regression. These are separate runs,
  not distinct totals to combine.
- ESLint completed with **0 errors, 27 warnings** (translation helpers and
  formatting; inherited shell formatting warnings remain). The exact report is
  `ui-checked-eslint-log.txt`.
- RuboCop reports **11 existing offenses** in the touched reader/controller.
  Baseline checks using the exact accepted source via stdin reproduce the same
  11: `ui-rubocop-baseline-log.txt` and `ui-rubocop-final-log.txt`. New metadata
  formatting/complexity offenses were corrected. Full lint cleanup remains
  required before the normal ticket commit; no clean-Ruby-lint claim is made.
- `git diff --check` passed. Frozen pnpm 10.2.0 dependencies were installed in
  this worktree; no donor node_modules, dependency/lockfile changes or hook
  bypass were used. Provider calls in tests are synthetic/stubbed.

Red/green iteration logs are preserved. First tests for newly introduced
components failed during module collection because the component did not yet
exist; these are explicitly not assertion-level behavior reds. Existing-route,
revision conflict, scope/export, typed reader metadata, identity editing,
obsolete response and ordering cases have assertion-level failing logs before
correction. These development iteration logs do not claim independently frozen
source trees for every iteration; the two full frozen UI checkpoints are listed
above. Prior delivery 246/0 and 57/0 results remain in their separate evidence
package and are not relabeled as results for this UI source.

## Inventory

The full final tree contains 9,685 blobs: **8,962 non-release paths** and 723
existing release-evidence blobs. `ui-checked-non-release.sha256` matches exactly
the final Git tree path set excluding `docs/releases/`. All 20 runtime/test paths
changed in this UI slice, and all 103 runtime/test paths changed against accepted
base `9a834e756347822d4ae5af15f268a5e8751fc852`, are included. Delta inventories and
`ui-checked-inventory.json` provide the complete path lists and counts. This
package adds only release evidence, without ignored runtime or generated product
artifacts.

## Remaining R09 criteria and allocation

1. Coordinator source/standards re-review and any resulting corrections.
2. Full relevant R09 regression and lint cleanup, production frontend build and
   normal-hook ticket commit after checks/review; no commit is made here.
3. Allocated in-app browser validation of real signed-in settings save/reload,
   typed/custom and empty/disabled question/rule forms, currencies/revisions,
   Offer selection, source/correction views and responsive layout. Then verify
   the saved configuration against representative incoming qualification in the
   local product. The prior Mac lock blocker has not been freshly checked in
   this interval; browser/server ownership is still reserved to root.

The focused interval and 15-minute extension covered only serial local checks.
All owned test/lint processes completed; the interval is released to root. No
full build, application server, browser session, integration or deployment was
started by this task.
