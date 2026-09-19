# R14 Pilot Verification Checkpoint

Worktree: `/Users/ghalyasaid/.codex/worktrees/r14-alerts-pilot/AI Chatbot`
Branch: `codex/r14-alerts-pilot`
Baseline: `5834d354fcadad4f5825582dab9db5de098fa1b1`

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
