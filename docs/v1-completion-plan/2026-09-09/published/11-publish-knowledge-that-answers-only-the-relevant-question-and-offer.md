# R11 — Publish knowledge that answers only the relevant question and Offer

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/15

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can approve business knowledge and a Lead receives a supported, context-aware answer.

## What to build

Deliver an end-to-end draft → approval → retrieval → answer path with explicit live/draft status, immutable source revisions and constrained commercial claims.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Knowledge has Documents and Answers, with clear draft/published or approved states and a distinct approvals view.
- [ ] Drafts, archived content and unapproved edits cannot be used; retain enough version content to reconstruct the source of an answer.
- [ ] Retrieval respects Business Account, Offer, validity and language; conflict handling cannot silently choose contradictory pricing or refund facts.
- [ ] Use bounded recent Conversation context and corrections without mixing private notes into public answers.
- [ ] Amounts, links, guarantees and eligibility claims are validated against approved facts or rendered from trusted structured content; unsupported claims go to Review.
- [ ] English/Swahili sensitive questions, irrelevant sources, injection, unsupported media and partial provider output have demonstrated safe outcomes.
- [ ] Try this answer opens the same authorized test experience via a contextual shortcut, not a duplicate testing system.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/26 (R09).
- https://github.com/drsaidsaid/ai-chatbot/issues/27 (R10).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
