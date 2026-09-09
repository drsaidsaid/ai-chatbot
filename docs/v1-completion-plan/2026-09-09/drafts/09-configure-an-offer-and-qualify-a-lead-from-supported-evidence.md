# R09 — Configure an Offer and qualify a Lead from supported evidence

Status: Draft for breakdown review; not published and not assigned.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/8

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can set an Offer's questions and thresholds, and a Lead receives the correct next question and Qualification.

## What to build

Complete Business & offers settings and connect them to qualification behavior. Use the standalone product's rules, including English/Swahili/TZS evidence and negation; keep Online Profits selling-model changes separate.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Create/edit an Offer and its approved qualification questions, budget ranges and rules in the same settings path.
- [ ] Display currency in human units with a currency label; correctly round-trip stored units without a hundredfold change.
- [ ] Positive evidence, negation, unknown information and later corrections remain distinguishable and linked to the source message or human edit.
- [ ] Clear Swahili/TZS cases and negated English cases no longer qualify solely because keywords/fields are present.
- [ ] Ask one relevant question at a time without repeating an answered question; apply the current Offer's rules rather than another Offer's.
- [ ] Show quality, reason, evidence, missing signals and next action in Lead and Conversation views; configuration changes invalidate affected evaluation evidence.
- [ ] Verify saved rules through a representative incoming conversation and resulting Qualification.

## Blocked by

- R02 (replace with the published GitHub issue reference after approval).
- R03 (replace with the published GitHub issue reference after approval).
- R05 (replace with the published GitHub issue reference after approval).
- R06 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
