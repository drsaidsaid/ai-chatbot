# R05 — Honor a natural-language stop request in the live conversation

Status: Implementation and focused verification complete on the ticket branch;
awaiting coordinator integration and in-app acceptance. R03 and R04 were accepted
and integrated at `324ee6df9ca50dff708f41a4004cd105b23a784b` on 10 September 2026.

## Parent

https://github.com/drsaidsaid/ai-chatbot/issues/10

This is a focused completion/correction slice under the existing feature. Do not close or modify that parent as part of ticket publication.

## User story covered

A Lead can ask to stop and the app immediately stops automated contact.

## What to build

Wire opt-out recognition and persistence into canonical incoming processing and dispatch cancellation, with a clear status in the Conversation and Lead detail.

Work within the owned Community Edition Rails/Vue product. Deliver the real narrow path across every relevant storage, API, job/provider and UI boundary; do not mark a screen or sandbox stub as completion of the behavior.

## Acceptance criteria

- [x] English, Swahili and mixed-language stop/refusal cases are tested with explicit distinction between opting out and unrelated negated phrases.
- [x] A recognized opt-out is stored durably with source message/time and appears in the authorized operator view.
- [x] Pending AI messages and follow-ups are canceled or blocked at dispatch; repeat events do not create duplicate effects.
- [x] Reordering, retries, later takeover and restart cannot silently restore messaging eligibility.
- [x] Re-consent requires a new explicit supported action and recorded evidence; resuming AI alone does not clear opt-out.
- [x] Prove canonical ingress → recorded stop → blocked send with an isolated provider and queue.

## Blocked by

- Accepted: https://github.com/drsaidsaid/ai-chatbot/issues/20 (R03).
- Accepted: https://github.com/drsaidsaid/ai-chatbot/issues/21 (R04).

## Current implementation contract

- Public acceptance seams confirmed by the coordinator: signed canonical
  ingress, access-scoped Conversation and Lead reads/UI, administrator
  re-consent from a newer explicit Inbound Message, and R04 dispatch/recovery
  races.
- Stop recognition lives in a focused consent module called before Channel
  Greeting and AI intent creation. It does not modify the shared conversation
  intent classifier or orchestration processor.
- Stop takes precedence in mixed complaint, refund, support, and human-request
  text. Preserve the Inbound Message for operator review and send no automated
  acknowledgment. R05 does not import or depend on the unaccepted R11 candidate.
- Re-consent records evidence and sends nothing. AI resume is separate and
  cannot clear suppression or revive old work.

## Evidence and scope

Based on the 9 September 2026 standalone UI/UX audit and the standalone portions of the functional/integration audit. Apply relevant product requirements and ADRs before building. Current UI audit fixtures do not prove production behavior. Test behavior changes first, run the relevant checks/build, inspect the in-app browser path, review the diff and record evidence before completion.

## Focused verification evidence

- Signed canonical webhook coverage proves direct English, Swahili, and mixed
  withdrawal, quoted and negated controls, immutable evidence, no greeting, no
  AI intent, no provider request, replay idempotence, AI resume separation,
  administrator-only evidenced re-consent, and access-scoped reads.
- Multi-Conversation coverage proves pending AI intents and deliveries are
  invalidated and a late follow-up cancels before recording a send.
- Independent-worker barriers prove both R04 orders: withdrawal first cancels a
  claimed delivery before provider HTTP; provider authorization first preserves
  its one accepted result and blocks the next automated reply.
- The final post-review Rails matrix is green. The public consent request file
  passes 11 examples, the isolated concurrency/legacy compatibility set passes
  4 examples, and the Vue/API set passes 23 tests. Focused RuboCop, ESLint, and
  normal commit hooks are clean.
- Final review follow-up: the signed mixed stop/complaint/refund/support/human
  case and access-scoped Conversation-list suite pass in the 11-example public
  request file; isolated concurrency/legacy compatibility passes 4 examples.
  Consent list queries are fixed at 2 for both one and five Leads with real
  three-event histories, while only one latest event is loaded per Lead.
- In-app desktop acceptance proves the Swahili stop and immutable evidence are
  visible, Resume AI leaves withdrawal intact, explicit administrator re-consent
  changes only consent to permitted, and the owned Inbox then shows the newer
  evidence. A 390×844 phone viewport keeps the consent card visible above the
  composer. The exact production build completes successfully.


## Execution coordination

The owner approved implementation of all 18 completion tickets in separate Codex tasks until completion. Respect blockers and use the coordinator integration branch codex/v1-completion-20260909 as the source of integrated predecessor work after R01 validates it. Do not implement against the older saved checkout. Each task owns its focused branch and commit/PR evidence; the coordinator alone combines ticket work on the integration branch. Use the in-app browser for all browser validation.
