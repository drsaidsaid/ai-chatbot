# R09 — Configure an Offer and qualify a Lead from supported evidence

Status: Approved for implementation; blocked by the issues below.

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

- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).
- https://github.com/drsaidsaid/ai-chatbot/issues/20 (R03).
- https://github.com/drsaidsaid/ai-chatbot/issues/22 (R05).
- https://github.com/drsaidsaid/ai-chatbot/issues/23 (R06).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of the amended V1 completion programme in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.


## Approved 12 September product amendment

These criteria supersede conflicting earlier wording. Follow ADR 0016 and the approved product agreement. Existing evidence remains historical; verify the revised contract before acceptance.

- [ ] Qualification has explicit not-configured, disabled and enabled modes per Offer. Missing or intentionally empty rules never resurrect a global interview, classify rejection or make up evidence.
- [ ] Replace fixed business-existence, revenue, lead-volume, urgency/budget/authority gates with business-defined typed criteria. Separate fit, readiness and action eligibility; display reasons and missing facts plainly.
- [ ] Owners can configure information needed and suggested wording; the agent skips known facts and asks at most one useful relevant question, not after every answer. No fixed two-answer quota.
- [ ] Support product, service and programme Offers. Preserve reviewed OfferDeliveryContext, version invalidation, financial evidence precision, correction history, consent and lock/delivery contracts. Online Profits values are editable fixtures, not runtime constants.
- [ ] Scope ownership: this ticket owns configurable qualification runtime; R19 owns document interpretation/guided publishing, R20 authoritative prices, R25 ad-set selection. No duplicated editors or parallel sender.
