# R01 — Reproduce and document one canonical V1 release

Status: Approved for implementation; ready to start.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/11

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An owner can identify exactly which version is being tested and released.

## What to build

Boot a clean copy of the audited release candidate, reconcile later donor work deliberately, and bind the product requirements and proof record to one chosen release. Update the navigation and standalone scope documents before implementation begins.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Record the chosen commit, dependencies, migration set and local startup path; compare it with the audited commit 74d156e327e3ddb2deedd1503c6d1c04b0b1359e.
- [ ] Preserve dirty work and donor branches; do not silently replace the Community Edition Rails/Vue runtime or import enterprise code.
- [ ] Prove a clean install and database migration/boot with isolated fixtures; preserve the MIT notice.
- [ ] Reconcile requirements for basic analytics versus hidden generic CE reports, and record the approved five-item navigation and one WhatsApp connection scope.
- [ ] Create a mapping of existing issues, claimed completion and current acceptance evidence; leave existing parent issues unchanged in this task.
- [ ] Record remaining release-environment or provider decisions explicitly so later tickets do not invent them.

## Blocked by

None — can start immediately.

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
