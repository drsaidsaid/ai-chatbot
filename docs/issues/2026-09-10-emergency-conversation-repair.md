# Emergency: acknowledge eligible Reviews and route customer requests correctly

Status: Reviewed implementation candidate; acceptance remains blocked by the
unchanged HQ qualification-semantics case and full R11 scope. Starting development
foundation `404c92cdf58447fd65c9d84687ea88fd7711c536`. Full R11 remains incomplete.

The branch now uses exact combined development base
`1aa85090f638c6140aa42939a8d1355762452ab4`, including the reviewed R06 invitation
correction, R09 qualification source through `a161af2`, and R04 caller locking
from `59a3bbf`. The coordinator additionally authorized the exact extractor
correction from R09 `00190e4` after this branch reproduced false informational
evidence through actual jobs and later history replay. The subsequent context correction from `111345d` is also ported exactly and
independently reviewed. No private ancestry is merged.

The coordinator approved the scope, fixed-copy candidates, public test seams and
test-first sequence in
`docs/releases/2026-09-10-emergency-conversation-repair/PLAN.md`.

## Demonstrable path

An eligible public inbound complaint, refund/support action, knowledge Review or
provider failure produces the correct persisted disposition and at most one
fixed customer acknowledgment through the owned R04 Message/outbox path. It
does not fabricate an answer, force sales qualification, lose failure evidence,
duplicate a send or override a Human Operator. Ordinary greetings and supported
qualification statements do not create false no-knowledge Reviews.

## Acceptance

- Transactional complaint/refund/support requests precede qualification/handoff;
  informational policy questions preserve approved knowledge and source authority.
- Genuine English/Swahili staff requests follow the configured policy; ordinary,
  negated and quoted mentions of sales/person/agent do not falsely trigger it.
- Persist Review before claiming it exists. Keep blocked/failure metadata,
  render fixed copy without model output, and omit sales questions on Review
  acknowledgments. Acknowledge only the explicitly supported inbound paths.
- Record one Message/outbox identity per intent, enqueue outside the owning
  transaction on success and provider rescue, and retain R04 claim/control,
  assignment, opt-out, launch, window, greeting and human-activity checks.
- Exhausted expired claims retain their failed state and attempt budget while
  recording one eligible acknowledgment and configured alerts. Live claims and
  revoked authority remain silent. Queue failure must preserve committed records.
- Greetings, language questions and supported qualification statements use their
  own reply path; a greeting-prefixed business question still reaches retrieval.
  Consume R09's next question directly and retain its displayed-prompt metadata.
- HTTP failure/truncation fixtures, duplicate/recovery/race cases and actual
  persisted orchestration outcomes pass. Do not count an acknowledgment as a
  supported answer or a recorded Message as a provider-delivered message.

## Coordination and exclusions

R09 owns parser/evidence/qualification corrections and contextual short-answer
capture. Its Result contract is unchanged; no overlapping renderer/classifier/
IntentProcessor edits are planned. Heavy Rails checks use the coordinator's
assigned slot. Final acceptance requires combined actual-job/delivery checks,
retained coupled checks and independent review of the final immutable source;
the development foundation is not an accepted V1 release.

No semantic selector, knowledge publication, Offer-specific rules, post-handoff
notice exception, global Review callback, frontend shell, live state mutation,
external message, deployment or private-history push is authorized here. The
observed 6/20 ordinary source-selection limitation remains explicitly unresolved.

## Candidate verification

Final combined checks: 97/1; routing/fixed replies: 85/0; strict Ruby lint: 18 files,
0 offenses. Both final independent source reviews have no actionable findings and
verified all 18 hashes. The original `can spend $2500` positive handoff expectation
is retained and still fails; the explicit-budget comparison and corrected budget
context workflow pass. See the release handoff and checks for the exact scope.
This candidate does not close R11 or authorize deployment.
