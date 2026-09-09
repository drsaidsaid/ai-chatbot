# R17 — Approve launch only from current test and pilot evidence

Status: Draft for breakdown review; not published and not assigned.

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

- R02 (replace with the published GitHub issue reference after approval).
- R03 (replace with the published GitHub issue reference after approval).
- R04 (replace with the published GitHub issue reference after approval).
- R05 (replace with the published GitHub issue reference after approval).
- R06 (replace with the published GitHub issue reference after approval).
- R07 (replace with the published GitHub issue reference after approval).
- R08 (replace with the published GitHub issue reference after approval).
- R09 (replace with the published GitHub issue reference after approval).
- R10 (replace with the published GitHub issue reference after approval).
- R11 (replace with the published GitHub issue reference after approval).
- R12 (replace with the published GitHub issue reference after approval).
- R13 (replace with the published GitHub issue reference after approval).
- R14 (replace with the published GitHub issue reference after approval).
- R15 (replace with the published GitHub issue reference after approval).
- R16 (replace with the published GitHub issue reference after approval).

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.
