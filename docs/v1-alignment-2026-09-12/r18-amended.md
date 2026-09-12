# R18 — Deploy a recoverable release and complete a supervised V1 pilot

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/7

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

The owner can operate the deployed app, stop automation and recover data before wider use.

## What to build

Verify the selected hosting environment, release artifacts and operational recovery, then carry out the separately authorized supervised pilot. This is a production-readiness verification slice, not a claim that infrastructure is currently broken.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Identify and record the actual hosting environment/VPS, deployment SHA, database migrations, workers, schedules and required persistent storage.
- [ ] Verify TLS/session/signup configuration, encrypted secrets, redacted logs, backups and a successful restore rehearsal using the selected environment.
- [ ] Monitor receipt/queue lag, failed delivery, failed jobs, provider health and usage limits with one useful owner alert per incident.
- [ ] Pause and rollback stop pending automated sends while preserving human access and durable incoming records; recovery cannot replay stale outreach.
- [ ] Use authorized provider test assets and an explicitly approved small supervised live pilot; do not activate payments, Online Profits sync or bulk nurture.
- [ ] Capture actual browser, service, backup/restore and pilot evidence against the deployed version; fix failures before expanding traffic.
- [ ] Provide a short operator guide for daily work, escalation, stop/restart and incident recovery.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/34 (R17).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of the amended V1 completion programme in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.


## Approved 12 September product amendment

These criteria supersede conflicting earlier wording. Follow ADR 0016 and the approved product agreement. Existing evidence remains historical; verify the revised contract before acceptance.

- [ ] Deploy only the fully integrated amended programme after R17. Preserve customer/provider credentials, payments and ledgers through rehearsed migration/rollback and distinguish estimates from real receipts.
- [ ] Supervised pilot includes approved test recipients, Google Calendar, ad metadata/template assets, managed AI and manually verified test payments. No broad live audience broadcasts or unbounded provider spend are implied. Final public branding and prices require approved real values.
