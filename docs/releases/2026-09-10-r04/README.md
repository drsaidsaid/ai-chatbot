# R04 — eligible outgoing replies and safe recovery

Backend and component acceptance is verified. **In-app browser acceptance is
pending the coordinator's allocation after R06.** Issue #21 remains open and
unintegrated. No customer provider, paid model call, live launch approval or
external messaging was used.

Branch: `codex/r04-outbound-delivery-20260910`.
Base: integrated R03 `f2b184e1c332f0bf68c31dec460f7e5599657a72`.
Implementation commit: `4b5379610dafb948f5ff83fc347bc9355c9d4a5f` (normal repository hooks ran).
Coordinator correction commit: `ca117f6bb37731ef104e797a85adc90ba107777f` (normal repository hooks ran).
Receipt alias correction commit: `562c6f407d2f489ee13c39a68837b1feb5ed0ca1` (normal repository hooks ran).
Browser correction commit: `4c5ce8e6c0dec222bcd40d300cd18a270c8c2eaa` (normal repository hooks ran).
Decision: [ADR 0011](../../adr/0011-owned-whatsapp-outbound-delivery.md).
The coordinator alone integrates this branch.

## Result

Each outgoing WhatsApp Message records one durable delivery. Competing workers
share an owner claim; dispatch authorization rechecks current account, operator,
conversation, launch, opt-out, connection, recipient and template/window state.
Control actions cancel pending automation. Remote model and provider calls run
outside the Conversation lock. A greeting must be accepted before an automated
answer from the same control version can dispatch.

A definite rejection or preparation failure is failed; uncertain acceptance is
unknown, creates one local Review Request and cannot be retried automatically or
through the generic Inbox retry action. A late acknowledgment from the original
owner can reconcile that review. Provider acceptance remains separate from
verified sent/delivered/read status. Recovery repairs lost enqueues and abandoned
claims in bounded batches. Legacy messages without provider IDs become unknown
on upgrade and are not replayed.

The existing Rails/Vue sender, Message API, Inbox components and CE media path
remain in use. R06's current-member/current-assignee policy contract was applied
at dispatch; its unintegrated branch and dispatch-time media capability were not
copied or replaced.

## Validation

- **306 selected Ruby examples passed** after the delayed-creation corrections, including 51 canonical outgoing cases,
  two real Rails-process kill cases, R03 ingress/concurrency, existing canonical
  launch flow, orchestration, domain outbox, follow-up, handoff/review/booking,
  both WhatsApp providers, native Message/Bookings/Review APIs, the Message builder,
  nine independent-connection authority cases and five booking notice cases.
- **56 Vue tests passed**, including 31 Inbox cases against the actual store and MessageList/Message/MessageMeta/MessageError
  components: pending/canceled/unknown display, acceptance awaiting receipt,
  projected sent/delivered/read advancement, provider failure, retry eligibility
  and ten client evidence aliases passed through the real deep camel-case
  transform using actual HTTP response fixtures, plus individual owned outcomes
  within same-minute groups, delayed creation after outcomes, optimistic reply
  reconciliation and preserved ordinary grouping. The remaining 25 cases cover
  existing conversation mutations and helpers.
- **Latest production Vite build passed**, 4m33s, 5,078 modules. Existing Browserslist and bundle-size
  warnings remain. No dependency or lockfile change was made.
- Strict Ruby lint passed on all three changed Ruby files. The changed frontend
  store and list test pass lint with no errors or warnings. Earlier full-branch
  evidence retains one finite translation-key mapping warning.
- Fresh schema and exact R03 checkpoint upgrade match canonical schema hash
  `ff7f8e39a5a0efe2eea6f069d6b1a17a60721fa30a286526defcfc504cbeb707`.
  A separate migration regression proves legacy unknown/accepted evidence is
  idempotent and uncertain messages are never queued for replay.
- [Standards and Spec review](review.md): all reported findings resolved and
  rereviewed. Red/green evidence includes malformed preparation, formatted
  recipients, tenant scoping, greeting ordering and explicit resume.

The Ruby suite exercises application jobs and APIs, separate database
connections, and an actual loopback HTTP provider in separate Rails processes.
One killed worker stops before dispatch authorization commits; another stops
after the provider accepts but before the Message ID commits. Recovery sends
once in the former case and raises one unknown review without resending in the
latter. These are canonical-path checks, not evaluation-sandbox labels.

The latest backend/frontend/lint results use `created-order-*` logs.
[Delayed creation and reconciliation evidence](created-order-corrections.md)
records the canonical queued-event and actual store/list regressions.
The previous 301-example/25-Inbox run uses `browser-fixes-*` and
`browser-grouping-green.txt` logs.
[Browser-discovered correction evidence](browser-corrections.md) records the
actual stale live broadcast and hidden grouped metadata, their regressions and
targeted rereviews. The corrected desktop/phone walkthrough remains pending.
The 292-example receipt correction uses `receipt-alias-*` logs. The previous 291-example and
8-component correction run and successful production build use `coordinator-*`
logs; no production frontend source changed in the final alias correction.
The earlier 235-example run and original build remain preserved as initial
implementation evidence.
[Coordinator correction details](coordinator-follow-up.md) map each regression to
its red/green evidence and define the narrow booking scope.

Logs and [SHA-256 manifest](SHA256SUMS) are in this directory. All fixtures are
synthetic. Frozen audit artifacts were not modified.

## Reproduce the local checks

Use the fresh-dependency procedure in the R01 runbook, Ruby 3.4.4, Bundler 2.5.16,
Node 24.13.0 and pnpm 10.2.0. Load a private local environment with fresh encryption
keys. Do not publish it. This task used its own PostgreSQL 55484 and Redis 6394.
The spec suite uses only the Rails test database; concurrency groups commit and
truncate their test fixtures, so do not run another suite against that same
database at the same time. Process-provider ports are allocated ephemerally.

```sh
bundle exec rspec spec/requests/whatsapp_outbound_delivery_spec.rb \
  spec/jobs/action_cable_broadcast_job_spec.rb \
  spec/requests/whatsapp_outbound_crash_spec.rb \
  spec/requests/whatsapp_alert_authority_spec.rb \
  spec/requests/whatsapp_booking_notice_spec.rb \
  spec/requests/whatsapp_ingress_spec.rb spec/requests/whatsapp_concurrency_spec.rb \
  spec/requests/ai_lead_employee/end_to_end_canonical_launch_proof_spec.rb \
  spec/jobs/ai_lead_employee/outbox_dispatch_job_spec.rb \
  spec/jobs/ai_lead_employee/orchestration_intent_job_spec.rb \
  spec/services/ai_lead_employee/orchestration_intent_recorder_spec.rb \
  spec/services/ai_lead_employee/human_review_request_service_spec.rb \
  spec/services/ai_lead_employee/highly_qualified_handoff_service_spec.rb \
  spec/services/ai_lead_employee/booking_service_spec.rb \
  spec/services/ai_lead_employee/follow_up_delivery_service_spec.rb \
  spec/services/conversations/control_service_spec.rb \
  spec/services/conversations/message_window_service_spec.rb \
  spec/services/whatsapp/send_on_whatsapp_service_spec.rb \
  spec/services/whatsapp/providers \
  spec/controllers/api/v1/accounts/conversations/messages_controller_spec.rb \
  spec/controllers/api/v1/accounts/bookings_controller_spec.rb \
  spec/requests/api/v1/accounts/human_review_requests_controller_spec.rb \
  spec/builders/messages/message_builder_spec.rb
pnpm exec vitest --run \
  app/javascript/dashboard/components-next/message/specs/WhatsappDelivery.spec.js \
  app/javascript/dashboard/components-next/message/specs/WhatsappDeliveryList.spec.js \
  app/javascript/dashboard/store/modules/conversations/specs/mutations.spec.js \
  app/javascript/dashboard/store/modules/specs/conversations/helpers.spec.js \
  --minWorkers=1 --maxWorkers=1
RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=6144 pnpm exec vite build
```

## Pending in-app browser acceptance

The running fixture uses `ale_release_r04_browser`, Rails 3224 and a loopback
provider on 3225. [seed_outbound.rb](../../../script/release/whatsapp/seed_outbound.rb)
refuses an occupied or non-test browser database and requires the local provider.
[fake_outbound.mjs](../../../script/release/whatsapp/fake_outbound.mjs) cannot send
callbacks or contact Meta. Login is `r04-operator@example.test`; the password is
kept only in the private local environment. Account 1, Conversation display ID 1.
The login page returned HTTP 200; that is a server probe, not browser acceptance.

The six seeded display states are **fixtures**. Their database states were
verified through actual sender/control/projector services and are recorded in
`browser-fixture-states.json`. They do not count as an operator interaction proof.

After allocation, use only the in-app browser to:

1. Inspect the real Inbox at desktop and phone widths, including reload persistence
   of pending, canceled, failed, unknown, accepted and later delivery-failure states.
2. Confirm unknown and accepted-but-provider-failed messages offer no generic retry;
   a definite pre-acceptance failure permits the authorized retry action.
3. Create at least one new reply as the operator through the Inbox. Observe its
   saved pending state, then execute its real SendReplyJob on this local Rails
   stack (test-mode queues are deliberately held). Verify the loopback request,
   provider acknowledgment, Inbox update and persistence after reload.
4. Exercise a new reply beginning `Failed:` (definite rejection) and `Unknown:`
   (uncertain provider outcome), checking honest controls and one local review.
5. Record screenshots and API/database evidence, report the result to the
   coordinator, and leave integration/issue closure to that task.

After explicit allocation, R04 opened its own in-app tab and created/dispatched
a new operator reply. This exposed the corrected broadcast/grouping defects.
The browser was then released while fixes were checked. No lock-screen retry,
new unlock request or R06/Meta tab interaction was made by R04.
