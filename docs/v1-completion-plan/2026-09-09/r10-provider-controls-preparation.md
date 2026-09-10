# R10 provider controls: refreshed preparation

Status: Candidate implementation and acceptance complete on the focused R10
branch. Coordinator integration remains pending.

Reviewed baseline: `324ee6df9ca50dff708f41a4004cd105b23a784b`.
Issue: [R10 #27](https://github.com/drsaidsaid/ai-chatbot/issues/27).
R01, R02 and R06 are accepted in this baseline; R04 is also integrated.
The coordinator released implementation against this exact baseline. This
supersedes the earlier preparation against `5c3bbc2f`.

## What the integrated source now supplies

| Boundary | Current source and consequence for R10 |
|---|---|
| Settings and access | `OwnedSettingsLayout.vue` surrounds provider and Test Center routes. `AiTestingPage.vue` links to both. R10 completes the connection panel inside this layout and retains the admin-only route/API contract. R06 supplies current membership and account isolation. |
| Credentials | `AiProviderConnection`, its account-scoped controller, and `ClientFactory` retain the encrypted OpenRouter boundary. Saving credentials still makes the UI say Connected without a successful readiness check. |
| Readiness | `HealthCheck#perform` requests 8 output tokens. `IntentProcessor#build_provider_answer` explicitly requests 64; `OpenRouterAdapter#complete` defaults to 512. These are three different budgets, not one configured answer policy. |
| Model work | R04 commits a claimed intent, calls the provider outside the Conversation lock, then rechecks ownership, control and sources. R10 extends this fence; it does not restore the former long transaction or implement a second claim system. The R04 qualification-lock correction is still separately in progress. |
| WhatsApp delivery | Every sender reaches `OutboundProviderGuard` / `OutboundDispatch`. `OutboundEligibility` checks WhatsApp health and other authority, but not AI-provider disablement or usage allowance. R10 adds its permission check here, rather than trusting only the domain outbox job. |
| Usage and launch | `Response` discards usage/cost. `SandboxRunner` rolls back its simulation transaction despite potentially calling the provider. `ReportBuilder` selects reviewed runs without provider-version matching. R04 already cancels pending automation on launch withdrawal. |

## Regression to preserve

The coordinator supplied a production observation: a tiny probe succeeded while
a full 512-token request failed with HTTP 402, reporting capacity for only 49
tokens. The provider key had no separate per-key cap. This is evidence of the
readiness mismatch, not permission to perform another provider request or change
funding. Private account balance, credentials, browser captures and the broader
operational audit stay outside this public preparation document.

Reproduce the mismatch using a fake HTTP provider: an 8-token request succeeds;
the configured full-answer budget fails with insufficient credits. The visible
result must say the provider cannot currently answer at that budget, retain the
check time and safe recovery guidance, and never promote the small probe to
answer readiness. No lower-budget retry or fallback model may conceal failure.

## Narrow implementation contract

1. **One reply budget and honest status.** Store an explicit reply-token ceiling
   with the connection, initially 512 for new configuration, and share it with
   the R11 answer request and readiness test. Bound input size separately; a
   minimal prompt with the full output ceiling still does not prove capacity
   for every future prompt. Display exactly what was checked, model, budget,
   time and configuration revision. Saving is Configured / Not checked, not
   Connected or Ready. A successful check means that bounded request succeeded
   at that time, not funded indefinitely, launched, or quality-approved. A later
   real failure supersedes an older successful observation. Credential/model/
   budget edits invalidate readiness; stale concurrent checks cannot overwrite
   the new configuration. Do not derive spend capacity from key validity alone.

2. **A conservative enforceable allowance.** Add an admin-set daily maximum of
   authorized model attempts plus bounded input/output sizes. Use a documented
   UTC day and display the reset time in the account timezone. An unset/zero
   allowance permits no new model work; configuration must make this explicit.
   This is a request allowance, not a promise of a dollar ceiling. Count health
   checks, evaluations, real answers, retries and attempts with uncertain outcome.
   Exhaustion stops new model work and unsent automation, including output from
   a call still in flight. Increasing the allowance or reaching the next day
   never revives canceled Messages or stale intents. Keep timeout 15 seconds
   and no automatic HTTP retry initially; R04 recovery remains bounded and each
   additional provider attempt consumes a new allowance slot.

3. **Committed metering before HTTP.** The common provider client authorizes an
   attempt against fresh connection state and atomically reserves an account/day
   slot before calling the adapter. Record purpose, configuration revision,
   requested budget, start/end, sanitized outcome, actual response model, tokens
   and provider-reported cost when supplied. Missing or invalid numeric usage
   stays unknown, never a fabricated zero; aggregates must disclose incomplete
   cost coverage. Do not store prompts, replies or keys in the usage ledger.
   Concurrent requests cannot oversubscribe the allowance. A failed call, crash
   or rolled-back evaluation cannot refund an attempt that may have reached the
   provider. Evaluation admission/accounting must commit outside the simulation
   rollback boundary; a nested `requires_new` savepoint is insufficient. Refuse
   HTTP when durable admission is unavailable. Final storage mechanics must be
   proved against this contract before any real provider use.

4. **One provider-permission fence.** Preserve `ClientFactory.for(account:)` as
   the domain entry point and the existing classified `ProviderFailure` contract.
   Check the current connection/allowance again immediately before model work,
   and fence returned output by configuration revision as well as R04's intent
   owner, control and sources. Add the same stop/limit decision to
   `Whatsapp::OutboundEligibility` inside R04's dispatch authorization transaction.
   An explicit disable or exhausted local allowance cancels pending/claimed
   automation and prevents new admission. It does not retract already authorized
   dispatching work, alter its accepted/unknown evidence, or revoke ordinary
   Human Operator reply permission. Preserve provider-specific parsing inside
   the adapter; do not put raw provider errors into API or delivery payloads.

5. **Locking and cancellation.** Serialize provider configuration/allowance
   decisions on the same short-lived permission record used at final dispatch.
   Follow R04's Channel → ordered Conversations → delivery → originating
   authority order; any additional provider lock must use one compatible order
   across call sites. A connection mutation must release its provider lock
   before walking Conversations for cancellation. Committed revocation is checked
   at dispatch even if that cleanup is delayed or interrupted. No HTTP holds
   Conversation or permission locks. Reuse R04's cancellation/publishing path so
   the Inbox, domain outbox and persisted delivery agree. Do not introduce an
   Account → Conversation inversion with R06 membership cleanup.

   The implemented order is Channel → ordered owned Conversations → WhatsApp
   Outbound Delivery → AI Provider Connection for final send authorization, and
   Conversation → Intent → AI Provider Connection for returned output. Provider
   configuration writers commit and release their provider-only lock before
   Conversation invalidation. Provider HTTP holds none of these locks. The V1
   input ceiling is 32 KiB of serialized UTF-8 role/content bytes and is checked
   before ledger admission or HTTP; the output ceiling remains 1–4096 tokens.

6. **Configuration-bound launch evidence.** Use a non-secret configuration
   revision, separate from `updated_at` so routine health and usage writes do not
   invalidate evidence. Relevant provider/model/key/reply-budget/permission
   changes invalidate affected readiness and launch evidence. Evaluation snapshots
   carry the revision; legacy runs without it cannot certify the current provider.
   Preserve historical results visibly as stale. A successful health check or
   allowance reset must not approve launch. R17 owns the complete release-wide
   evidence fingerprint; R10 supplies the provider portion and mismatch guard.

## Interfaces with concurrent tickets

| Owner | Public contract / handoff |
|---|---|
| R04 | Extend the integrated model claim and final WhatsApp eligibility boundary. Preserve owner/lease fencing, current source/control checks, bounded recovery and the dispatch authorization point. Re-read its pending qualification-lock correction before touching `IntentProcessor`. |
| R06 | Keep every provider read, write, test, usage and limit operation admin-only and account-scoped, including revoked memberships and direct URLs. Never infer key presence for a Team Member. |
| R09 | Qualification/parsing corrections remain R09-owned. Provider accounting changes must not wrap qualification in new locks or change Offer evidence. |
| R11 | R11 owns common Review Request acknowledgments and the provider-failure reply path. R10 supplies classified failure, current provider revision, reply budget and a distinction between explicit stop/limit and provider-call failure. Do not build another failure acknowledgment in R10. |
| R17 | Consume the provider configuration revision in evidence selection and approval. Broader release, knowledge and qualification fingerprints remain R17-owned. |

Provider failure and an explicit automation stop are distinct. With automation
still permitted, an insufficient-credit/timeout/refusal result can reach R11's
one truthful, non-model Review acknowledgment through R04's outbox and delivery
checks. That acknowledgment must not claim an answer or staff availability.
Disabling the connection or exhausting the local allowance must not be bypassed
by labeling output an acknowledgment. Any purpose discriminator must be
server-owned and unforgeable through Message API attributes; no generic source
or control-check bypass is introduced. R11 owns the acknowledgment's applicable
source/control authority contract. Integration verifies both failure handling
and administrative stop behavior together.

## Acceptance through public boundaries

The completed checks exercise HTTP APIs, persisted records, actual job entry
points and fake-provider request accounting. The preserved evidence is in
`docs/releases/2026-09-10-r10/`.

| Scenario | Entry and required observable result |
|---|---|
| Save, rotate, disable, reload | Existing `/api/v1/accounts/:id/ai_provider_connection` GET/PATCH/DELETE; encrypted storage, empty browser key field, truthful not-checked state, no secret in response/error/logs. Test two accounts, Team Member denial, demotion and revocation for every operation including health/limits. |
| Small probe versus real capacity | POST `health_check` with fake 8-token success / full-budget 402; request uses configured reply ceiling, failure persists across GET and page refresh, clear credits guidance. A stale successful check cannot restore health after rotation, budget change or a later answer failure. |
| Usage and bounded failures | Drive actual health, evaluation and orchestration entry points through fake HTTP success, timeout, 401/403, 402, 429, malformed response and refusal. Verify exact request count, timeout/retry bound, token/cost reporting, unknown values and one recorded attempt per authorized HTTP operation. |
| Limit races and persistence | Independent workers compete for the last slot. Actual HTTP count stays within allowance; denied attempt and pause reason are visible. A crash or intentional evaluation rollback retains conservative accounting. Failed reservation produces no HTTP. Day rollover and limit edits never replay old output. |
| Disable/configure during work | Hold fake provider response; perform admin disable, rotate or change model/budget through PATCH/DELETE. Mutation completes promptly. Release response; old output cannot create a deliverable answer or overwrite current health. Metering of the old attempt remains visible. |
| Stop after Message creation | Create eligible automation through the real orchestration path; disable/exhaust before `SendReplyJob` or direct guarded WhatsApp sender runs. No Meta HTTP; delivery/outbox/Inbox expose cancellation. Also race at dispatch authorization and retain honest already-dispatching/unknown outcomes. Human replies retain R04/R06 permission checks. |
| R11 failure acknowledgment | Provider failure creates one Review Request and, when still permitted, one truthful acknowledgment through the common delivery. Duplicate processing, takeover, opt-out, stale sources, disabled provider and exhausted allowance cannot bypass authority or duplicate delivery. Coordinate this joint case after R11's path lands. |
| Launch evidence | Create/review evaluations through the sandbox API. Change provider configuration; old runs remain readable but cannot approve launch or authorize automated dispatch. New health/usage timestamps alone do not invalidate matching evidence or grant approval. |
| Browser | After runtime release, use this task's isolated in-app tab, real Rails API/database and blocked external traffic. Verify desktop and phone Settings → AI & testing → provider/Test Center, save/reload/failure/retry/limit/disable, accessible labels/focus, persistent Settings navigation and direct-route role denial. |

## Implementation and verification

No additional product or provider choice is required. ADR 0012 is reserved for
other coordinated work; R10 extends ADR 0007's decision and allocates no new ADR
number. The current branch is `codex/r10-provider-controls` from the exact
reviewed baseline. Implementation uses fake provider responses and isolated test
services. No live provider requests, key rotations, purchases, settings changes
or deployment are authorized. Final evidence must include the relevant Rails and
Vue checks, production build, in-app desktop and phone inspection, and a reviewed
commit. Local fake-provider acceptance is not funded production readiness or live
WhatsApp delivery proof.
