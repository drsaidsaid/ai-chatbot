# R17 — Approve launch only from current test and pilot evidence

Status: Approved for implementation; blocked by the issues below.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/14

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

An administrator can tell whether the exact current app and configuration passed the required checks.

## What to build

Complete Settings → AI & testing with readable scenarios, results and launch checks that bind evidence to the current release and relevant business/model/knowledge settings.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [ ] Use readable scenario names, actionable failures and Not tested instead of zero-failure percentages when no tests were run.
- [ ] Scenario and transcript panes adapt to content and phone size; the results path preserves selected scenario and context.
- [ ] Bind review evidence to commit, migrations, model/prompt/configuration, knowledge revisions and qualification rules; invalidate affected evidence after changes.
- [ ] A newer failure or unreviewed run cannot be hidden by an older reviewed pass; pilot counts link to real reviewed Conversations.
- [ ] Apply the approved V1 qualification and zero-serious-failure criteria, with the PRD's 50–100 simulated/low-risk conversation coverage rather than an editable count shortcut.
- [ ] Include canonical messaging, opt-out/takeover, role-scope, language, booking, follow-up and recovery scenarios.
- [ ] Verify the main journeys in the in-app browser at real desktop/phone widths, with keyboard, focus, naming, contrast and actual text/controls checked; no overflow-only signoff.
- [ ] Do not enable real delivery as a side effect of testing or saving draft review evidence.

## Blocked by

- https://github.com/drsaidsaid/ai-chatbot/issues/19 (R02).
- https://github.com/drsaidsaid/ai-chatbot/issues/20 (R03).
- https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).
- https://github.com/drsaidsaid/ai-chatbot/issues/22 (R05).
- https://github.com/drsaidsaid/ai-chatbot/issues/23 (R06).
- https://github.com/drsaidsaid/ai-chatbot/issues/24 (R07).
- https://github.com/drsaidsaid/ai-chatbot/issues/25 (R08).
- https://github.com/drsaidsaid/ai-chatbot/issues/26 (R09).
- https://github.com/drsaidsaid/ai-chatbot/issues/27 (R10).
- https://github.com/drsaidsaid/ai-chatbot/issues/28 (R11).
- https://github.com/drsaidsaid/ai-chatbot/issues/29 (R12).
- https://github.com/drsaidsaid/ai-chatbot/issues/30 (R13).
- https://github.com/drsaidsaid/ai-chatbot/issues/31 (R14).
- https://github.com/drsaidsaid/ai-chatbot/issues/32 (R15).
- https://github.com/drsaidsaid/ai-chatbot/issues/33 (R16).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.


## Execution coordination

The owner approved implementation of the amended V1 completion programme in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.


## Approved 12 September product amendment

These criteria supersede conflicting earlier wording. Follow ADR 0016 and the approved product agreement. Existing evidence remains historical; verify the revised contract before acceptance.

- [ ] Launch scope now includes every R19–R28 acceptance criterion plus original tickets; passing the original 18 alone cannot pass launch.
- [ ] Require representative editable Online Profits configuration, a no-qualification/no-call product business, and another service business; test English/Swahili answers, corrections, unknowns, human help and strict sales-call readiness.
- [ ] Include managed-provider access, manual payment/allowance/upgrade concurrency, ad-set future-ad mapping, approved template/broadcast consent, paid Offer prerequisite and model comparison evidence.
- [ ] No public brand launch until a suitable name is confirmed. LeadBloom checks found related existing brands and registered .com; keep working name meanwhile. Unconfirmed OPU prices and unpublished platform tariffs must not be quoted.

### Additional blockers

- https://github.com/drsaidsaid/ai-chatbot/issues/36
- https://github.com/drsaidsaid/ai-chatbot/issues/37
- https://github.com/drsaidsaid/ai-chatbot/issues/38
- https://github.com/drsaidsaid/ai-chatbot/issues/39
- https://github.com/drsaidsaid/ai-chatbot/issues/40
- https://github.com/drsaidsaid/ai-chatbot/issues/41
- https://github.com/drsaidsaid/ai-chatbot/issues/42
- https://github.com/drsaidsaid/ai-chatbot/issues/43
- https://github.com/drsaidsaid/ai-chatbot/issues/44
- https://github.com/drsaidsaid/ai-chatbot/issues/45
