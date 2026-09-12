# Bounded lifecycle review corrections

Ready for coordinator re-review; no integration or deployment performed.

## Correctness changes

- Alert admission reuses the authority object resolved and locked before the delivery suffix, including memoized absence. A record committed after that prefix cannot authorize the message.
- A non-context cancellation blocks the current unadmitted attempt even when its artifact was already context-canceled. Existing artifact cancellation reason/time and history remain intact.
- Conversation-wide cancellation refreshes current targets after Conversation ownership.
- The actual LeadQualification after-update-commit callback now owns the stable account/contact Conversation scope before evaluating its qualification-scoped follow-up relation. It catches a concurrently committed replacement for human_review, call_booked and closed, while preserving a different Offer's artifact in the same Conversation.

## Immutable trees

- Previous reviewed source: `96f72249b432d02004b940e974622c3d2c49e487`.
- Original corrections red comparison: `8d044743307e907e67ac96494caa11147a36cd46`, `refs/r09/followup-review-corrections-red-source-20260911`. Identical current regression specs, with only the six corrected services restored from the previous reviewed source.
- Original corrections candidate: `72cc1f48f4e5c38ab367d5f8f1725558ece0528a`, `refs/r09/followup-review-corrections-source-20260911`.
- Callback setup-only failed attempt: `1126be64c84063040fa288796b791984debf8c14`, `refs/r09/followup-callback-red-source-20260911`. Three fixture 422 failures; not behavior-red evidence.
- Actual callback race red: `b3c2eeee00dad333199994725f94ea77feb5c802`, `refs/r09/followup-callback-race-red-source-20260911`.
- Final corrected source: `1ede019dfa15f62b6d2ac3da4ffb106f642ac42d`, `refs/r09/followup-callback-corrected-source-20260911`.
- Evidence ref: `refs/r09/followup-review-callback-complete-evidence-20260911`. Its tree contains this directory plus the exact final source tree. The evidence tree SHA is supplied in the handoff, avoiding a self-referential file hash.

## Results and provenance

| Run | Result | Source / verification |
| --- | --- | --- |
| Original P1s plus snapshot race, replayed red | 5 examples, 5 expected behavior failures | 8d044743; every one of 9,633 tree blobs verified before/after |
| Original correction focused suite | 38 examples, 0 failures | development run before full frozen verification |
| Preserved broad compatibility | 246 examples, 0 failures | 72cc1f48; whole tree equal before/after |
| Actual callback races, red | 3 examples, 3 expected successor-remains-pending failures | b3c2eeee; whole tree equal before/after |
| Callback races, green | 3 examples, 0 failures | final production/test content before frozen narrow verification |
| Final affected-suite verification | 57 examples, 0 failures | 1ede019d; whole tree equal before/after; no pending examples |
| Ruby lint | 7 affected production files, no offenses | final production content |

The 246-example run belongs to 72cc1f48, before the callback correction. The final tree was checked with 57 examples across terminal invalidation, all lifecycle races, alert authority, follow-up scheduler and delivery suites. No claim is made that all 246 ran again on the final tree.

Exact final invocation: `callback-final-invocation.json`; pre/post: `callback-final-before.json`, `callback-final-after.json`; combined proof: `callback-final-verification.json`; results/log: `callback-final-results.json`, `callback-final-log.txt`.

Preserved broad invocation/pre/post: `lifecycle-corrections-combined-invocation.json`, `lifecycle-corrections-before.json`, `lifecycle-corrections-after.json`. Actual callback-red invocation/pre/post: `callback-race-red-invocation.json`, `callback-race-red-before.json`, `callback-race-red-after.json`. Original red comparison invocation and full-blob verification are in `lifecycle-corrections-red-verification.json`.

All tests use the established isolated local synthetic PostgreSQL/Redis allocation and provider stubs. Runtime credentials are not included. Initial resumed attempts using the default database or stale bundle path were environment errors, not test results. No real-provider HTTP, frontend build, hooks, branch integration or deployment occurred. Owned test/lint processes completed; runtime allocation is released to the coordinator.

## Inventory reconciliation

`callback-final-non-release-source.sha256` contains exactly the Git tree path set excluding `docs/releases/`: **8,952 paths**, with SHA256 for every file, including unchanged dependencies and all changed runtime/test paths.

The previous non-release count was 8,951. The only added non-release path is `spec/requests/ai_lead_employee/offer_follow_up_terminal_invalidation_spec.rb`; no non-release paths were removed.

The previously reported **9,633** count means **total tree blobs**, including **681** release-evidence blobs. It is not the non-release source count. `callback-final-all-tree-blobs.sha256` covers that total tree; `callback-final-inventory.json` records the counts and exact path-set comparison. The evidence package adds only this release directory; ignored/generated runtime artifacts are excluded.
