# R14 Pilot Verification Checkpoint

Worktree: `/Users/ghalyasaid/.codex/worktrees/r14-alerts-pilot/AI Chatbot`
Branch: `codex/r14-alerts-pilot`
Integrated baseline: `6c5b86590b5e19a9c8b850ad8fa6157893d8e02e` (initial work began from `5834d354fcadad4f5825582dab9db5de098fa1b1`)

## Completed validation

- Prepared isolated test database: `ale_r14_alerts_spec`.
- R14-specific Ruby tests passed: 5 examples, 0 failures.
  - `spec/requests/api/v1/accounts/alert_configuration_controller_spec.rb`
  - added human-review assignment example
  - added operational hot-queue example
- Affected Vue tests passed: 3 files, 16 tests, 0 failures.
  - `OfferConfigurationPanel.spec.js`
  - `OwnedSettingsLayout.spec.js`
  - `OperationalDashboardPanel.spec.js`
- Focused RuboCop passed: 10 files inspected, no offenses.
- Focused ESLint passed with no output.
- `git diff --check` passed.

## Broader-suite baseline failures

The focused related Ruby service run reported 14 examples, 3 failures. Each is present against baseline `5834d354fcadad4f5825582dab9db5de098fa1b1`, outside this R14 diff:

1. Human Operator visible-inbox access scope expectation.
2. Built-in review queue status expectation excludes `rejected`.
3. Human Operator performance scope expectation.

## Production build

One `bin/vite build` attempt transformed 5,092 modules then failed when Node reached its approximately 2 GB default heap limit (`FATAL ERROR: Reached heap limit Allocation failed`). No retry was run.

## Acceptance blockers / contract gaps

- Knowledge approval can be configured but has no delivery trigger.
- Default ownership is applied to human review requests, not a universal sales-handoff fallback.
- The UI supports assignee, admin, and member routes, but not an explicit WhatsApp-number route even though the API accepts it.
- Existing alerts do not yet demonstrate all required summary fields, canonical deep link, delivery history/status, retries, and recovery handling.

No real alert delivery, deployment, push, or integration was performed. No processes remain running from this verification work.

## Follow-up completion (after coordinator re-opened R14)

- Added `AiLeadEmployee::KnowledgeApprovalAlertDeliveryService`. A draft knowledge proposal now creates one idempotent, auditable WhatsApp alert per authorized configured recipient; the record retains recipient, queued/sent/failed status, message ID, provider ID, and error in `knowledge_approval_alert_deliveries` metadata.
- Added outbound authorization for `knowledge_approval`; delivery is canceled if the item is no longer draft or the recipient is no longer authorized.
- Wired this alert to successful `HumanReviewRequest#propose_knowledge!` requests.
- Exposed the existing validated direct WhatsApp route in the Team & Alerts UI.
- Focused new service test passed: 1 example, 0 failures.
- Focused Ruby lint covering new and changed backend files passed; focused ESLint and `git diff --check` passed.

## Integrated-baseline follow-up

Candidate was rebased from `5834d354fcadad4f5825582dab9db5de098fa1b1` onto integrated baseline `6c5b86590b5e19a9c8b850ad8fa6157893d8e02e`.

- Updated the dedicated R07 alert-authority concurrency fixture for the integrated booking-agreement contract and a mocked Google cancellation response.
- Added the legacy booked-call summary fallback when an existing booking has no Offer.
- Ran the formerly fixture-gated suite with `ALE_R07_CURRENT_DB=1` against its dedicated `ale_r07_current_20260913_spec` database and `POSTGRES_STATEMENT_TIMEOUT=120s`: 11 examples, 0 failures, 0 pending.

- Integrated-baseline focused alert paths: 34 examples, 0 failures (the R14 hot-queue example ran separately because three unrelated Operational Dashboard baseline assertions remain failing).
- Affected Vue paths: 3 files, 22 tests, 0 failures.
- The three unrelated Operational Dashboard baseline assertions concern Human Operator visibility, rejected review filter options, and Human Operator metrics; the R14 diff only adds the hot-queue example.

## Review repair follow-up

- Knowledge alerts use the canonical `/knowledge?knowledge_item_id=:id` route.
- Automatic and manual Human Review assignment synchronize the assigned canonical Conversation, preserve human-control audit history, and retain a `human_review_assignment` audit on the request.
- Explicit WhatsApp routes require a current Business Account member with the same verified alert phone; routing rechecks that membership at delivery time.
- Review alert text includes its canonical review-queue conversation link.
- Focused authorization and delivery tests: 17 examples, 0 failures. Focused RuboCop and diff checks passed.

## Final amended-contract completion

- Added administrator-only manual Review reassignment in the Review queue. It uses the canonical assignment endpoint, locks and synchronizes the Review Request and Conversation, preserves a later manual Conversation assignment during replay, and records assignment audit history.
- Added current knowledge-approval alert state to the approval UI and an administrator retry action. Retry resets the existing terminal outbound delivery under canonical authority locks and reuses the same Message, so it cannot create a duplicate alert.
- Handoff summaries now render every populated evidence field and use the published Offer question label when one exists. They retain qualification reasons, owner, contact, and the canonical Conversation link without depending on the original fixed interview vocabulary.
- Booking preparation alerts now include the canonical Booking queue link.
- Review and knowledge alerts have explicit outside-window coverage. Both pass through launch, alert authority, template, and WhatsApp response-window eligibility; plain-text delivery is suppressed with `message_window_closed` outside the window.
- Direct WhatsApp routes reload current settings and Business Account membership at creation and dispatch. A stale cached Account cannot retain a removed recipient or miss a newly saved authorized route.
- Crash/replay coverage proves a committed Review row with no assignment or delivery is reconciled idempotently. Dispatch rejects a stale Review assignee after Conversation reassignment.

Final focused evidence:

- Ruby alert/configuration/Review/knowledge/handoff/Booking paths: 39 examples, 0 failures.
- Vue Review and knowledge paths: 2 files, 14 tests, 0 failures.
- Dedicated PostgreSQL alert authority and concurrency suite: 11 examples, 0 failures, 0 pending.
- Focused RuboCop: no offenses. Focused ESLint: no errors; existing Knowledge panel formatting warnings remain. `git diff --check`: clean.

The coordinator prohibited another Vite build or browser run for this completion phase. The previously recorded integrated build passed at commit `7ef34819`; no real alert delivery, deployment, push, or integration was performed.

## Post-review concurrency repair

- Review alert Message creation and its JSON link now commit in one transaction while holding the canonical Conversation then Review Request locks. Concurrent replay produces one Message, and an exception after Message creation rolls the Message back so replay cannot orphan or duplicate it. Dispatch jobs use `ActiveRecord.after_all_transactions_commit`, so an enclosing orchestration rollback drops publication and an enclosing commit exposes the durable link before enqueue.
- Review assignment always invokes the two-record idempotency check. If the Conversation assignee is cleared while the Review retains the configured default owner, replay restores the canonical Conversation assignment.
- Knowledge creation and retry snapshot and lock every existing alert Conversation in stable order before the Knowledge Item, then compare the locked set with metadata reloaded under authority. Discovery of an unowned Conversation aborts the savepoint and restarts from a fresh prefix. Draft status is rechecked under lock, and retry visibility now requires live item/recipient authority plus an eligible terminal state below the attempt limit.
- Review alerts include reason and owner. Booking preparation alerts include owner.
- Focused service paths: 29 examples, 0 failures. Dedicated PostgreSQL concurrency/authority suite: 16 examples, 0 failures, including actual concurrent Review replay, enclosing-transaction commit/rollback publication checks, stale knowledge lock-set restart, and knowledge retry/dispatch workers.
