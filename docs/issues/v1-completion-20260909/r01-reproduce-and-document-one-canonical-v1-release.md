# R01 — Reproduce and document one canonical V1 release

Status: Locally complete; awaiting coordinator review and integration. GitHub #18 remains open.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/11

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An owner can identify exactly which version is being tested and released.

## What to build

Boot a clean copy of the audited release candidate, reconcile later donor work deliberately, and bind the product requirements and proof record to one chosen release. Update the navigation and standalone scope documents before implementation begins.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] Record the chosen commit, dependencies, migration set and local startup path; compare it with the audited commit 74d156e327e3ddb2deedd1503c6d1c04b0b1359e.
- [x] Preserve dirty work and donor branches; do not silently replace the Community Edition Rails/Vue runtime or import enterprise code.
- [x] Prove a clean install and database migration/boot with isolated fixtures; preserve the MIT notice.
- [x] Reconcile requirements for basic analytics versus hidden generic CE reports, and record the approved five-item navigation and one WhatsApp connection scope.
- [x] Create a mapping of existing issues, claimed completion and current acceptance evidence; leave existing parent issues unchanged in this task.
- [x] Record remaining release-environment or provider decisions explicitly so later tickets do not invent them.

## Blocked by

None — can start immediately.

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.


## R01 implementation and acceptance evidence

- Branch: `codex/r01-canonical-release-20260909`, from integration bootstrap
  `5c3bbc2f900948fcdd6729159701b9cc993b85b5`, whose runtime equals audited
  `74d156e327e3ddb2deedd1503c6d1c04b0b1359e`.
- Repaired the name-question migration's missing-predecessor-column failure.
  Added a forward migration for schema-only settings objects and defaults while
  preserving existing data; no Offer feature completion is claimed.
- Fresh CE-checkpoint upgrade and fresh current schema converge at 194 migration
  versions, 121 tables and version `20260909000100`.
- [Release proof and exact checks](../../releases/2026-09-09-r01/README.md),
  [development/test runbook](../../releases/2026-09-09-r01/runbook.md),
  [issue/evidence mapping](../../releases/2026-09-09-r01/issue-evidence-map.md),
  [release/schema ADR](../../adr/0008-canonical-v1-release-and-schema-provenance.md).
- Locked installations, production assets, isolated Rails/Redis/worker boot,
  synthetic browser sign-in and persisted Conversation, focused regression
  tests and Ruby lint are recorded in the proof. Frozen audit/plan files and
  saved-root donor source remain byte-identical; CE/MIT remains and enterprise
  is absent.
- No R01 local acceptance gap remains. Provider credentials/real delivery,
  Google OAuth/calendar proof, target deployment/restore and supervised pilot
  remain explicitly assigned to R03–R18. Navigation implementation remains R02;
  required basic analytics remains R16.
- The coordinator must review and integrate this commit before releasing
  successor blockers or changing GitHub completion status. No parent issue was
  changed, no customer message was sent, and no live launch gate was approved.
