# AI Lead Employee × Online Profits: integration readiness audit

9 September 2026 · Investigation and planning only

**Keep the owned Rails/Vue inbox and build on it, but do not enable unattended Online Profits conversations or proactive nurture yet.** The release candidate has substantial working architecture: tenant-scoped inboxes, durable AI intents, reviewed knowledge, human control, provider configuration, and evaluation screens. Its delivery, consent, qualification, and permission boundaries still have defects that can produce duplicate messages, messages after takeover, incorrect owner escalations, and exposure of information beyond a coach’s remit.

This is an assessment of source and isolated behavior, not a production certification. No application fixes, commits, deployments, migrations, account connections, real messages, production writes, or paid model calls were made. Only files in this audit directory were created.

## Decisions this audit supports

1. **Keep one messaging authority.** AI Lead Employee owns Meta webhooks, messages, delivery status, AI/human control, and the inbox. Online Profits owns the canonical Person, offers and participation, verified purchases/refunds, memberships, access, and observed lifetime value. Integrate through a narrow server-to-server contract; do not activate the separate OP WhatsApp sender as a competing authority.
2. **Use a People directory and an offer journey board.** A person can participate in several offers at once. The board should show automated progress as well as human work. Needs Attention is a small filtered work queue with evidence, reason, owner, and next action; it is not the whole CRM or a list of everyone who looks interested.
3. **Make the selling model fit OP.** TZS 100,000–200,000 entry offers should lead to approved information and online checkout. Said and his wife should receive meaningful decisions and exceptions, not routine discovery calls. Coaches support authorized program students. Monibullah should not receive generic chatbot agent access under current policies.
4. **Keep the September 25 webinar independent.** Registration, approved offer information, existing payment verification, access, and a manual support route must stand on their own. The chatbot can remain off or run offline/shadow evaluation while the webinar proceeds. This audit does not certify those separate webinar paths as ready.

## What stops unattended use now

| Priority | Finding | Evidence strength |
|---|---|---|
| P0 | Manual Cloud API setup can bypass webhook signature verification when the channel has no app secret. | Actual predicate reproduced; request spec explicitly expects this bypass. |
| P0 | Two workers can dispatch the same AI outbox message; ordinary AI replies can dispatch after human takeover. | Actual dispatcher methods reproduced with in-memory senders. |
| P0 | Live incoming processing does not call the opt-out service; the sandbox does. Ordinary natural-language stop requests are also missed. | Live call-site search plus actual parser reproduction. |
| P0 | Canonical intake lacks durable raw receipts, drops parts of batches, and can regress delivery state. | Static tracing; status batch/order behavior reproduced. |
| P1 | Negated English text becomes Highly Qualified; clear Swahili/TZS purchase intent produces no evidence. | Actual extractor and qualification scoring reproduced. |
| P1 | Current contact/qualification permissions do not implement program-only coach access. | Server policy and query inspection. |
| P1 | There is no complete OP Person/offer/consent/payment bridge; the existing OP WhatsApp projection merges by phone and stores one product/status view. | Both repositories inspected. |
| P1 | Approved sources are selected without offer filtering; generated answers lack factual validation and conversation memory. Booking is a placeholder, and live nurture scheduling is not wired. | Actual service paths inspected. |

P0 means a prerequisite for real customer messaging; P1 means a prerequisite for the corresponding OP integration or automated behavior. Detailed conditions and remedies are in the [technical audit](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/detailed-audit.md>).

## What was actually checked

The task’s checkout is **e2fa25a8**, older than both final-browser-qa **335d994f** and the local release candidate **74d156e3**. The release candidate is the principal audit target. A read-only remote check returned the same release-candidate SHA. The saved chatbot root is dirty at the older base and contains separate experiments; it must be reconciled deliberately. OP was inspected at **1da99f00 plus its current dirty working tree**, with hashes of relevant dirty files recorded. [Exact snapshots](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/source-snapshots.json>)

Eight safely isolated reproductions ran successfully: **8 runs, 14 assertions, no failures/errors/skips**. They confirm defects under the recorded conditions; they do not mean the application passes its acceptance tests. The harness loaded copied release-candidate methods with in-memory doubles, without booting Rails, touching a database, starting workers, or calling a provider. [Observations](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/evidence/offline-observations.json>) · [Verification record](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/evidence/verification.json>)

Repository launch notes report earlier Rails/Vue/browser checks. Those are historical evidence, not new verification. The queried GitHub Actions branch returned no runs. Production SHA, database shape, RLS, Meta account assets, credentials, template approvals, deliverability, backups, and operational monitoring were not verified here. The earlier OP platform audit was consulted for context; its live counts and deployment findings were not reverified or treated as fresh evidence. [Earlier OP audit](</Users/ghalyasaid/.codex/worktrees/a1cb/online-profits-next/docs/platform-audit/2026-09-09/README.md>)

## Delivery path

First establish one reproducible release and close the messaging safety defects. Then add the canonical Person and offer participation contract, scoped consent, and read-only purchase/access facts. Validate Swahili and mixed-language assistance against approved OP content before supervised live use. Add proactive nurture only after consent, template eligibility, cancellation, and recovery are proven end to end.

The [integration design and ticket roadmap](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/integration-roadmap.md>) contains ownership, identity rules, journey states, event contracts, acceptance tests, dependencies, operational recovery, and a webinar-safe rollout. The [current Meta requirements](</Users/ghalyasaid/.codex/worktrees/9b7a/AI Chatbot/docs/integration-audit/2026-09-09/meta-requirements.md>) distinguish platform rules from recommended product choices. There is no proposed dependency on a parallel frontend, an enterprise license, or a new payment processor.
