# Emergency repair candidate verification

Current foundation: `1aa85090f638c6140aa42939a8d1355762452ab4`.
Coordinator-authorized R09 context correction: exact current-tree port of the
extractor and two specs from `00190e4b6225dad0df132fdf730e549c6631564f`.
All three files were verified byte-for-byte against that immutable source.
The subsequent one-line contextual-fallback correction and its two specs were
ported from `111345dc2c58ed2e8f467f2ee1b1ce8cd77ec7e6` with coordinator authorization;
the resulting extractor and those specs also match that immutable source byte-for-byte.
Exact reviewed source content is pinned by `source-sha256.json`; summarized checks are in `checks.json`. This candidate is not release acceptance.

| Check | Result | Local evidence |
|---|---|---|
| Before processor edits: same seven retained knowledge/provider/orchestration/fixed-reply/canonical-launch files as the earlier pilot | 92 examples, 0 failures | `tmp/emergency/foundation-preservation.log` |
| Complaint requesting a human, through the actual orchestration job | 1 example, 1 failure before the fix: qualification reply and evidence, no Review | `tmp/emergency/complaint-orchestration-red.log` |
| Complaint job after the fix, including duplicate execution and persisted outcome checks | 1 example, 0 failures; no qualification record, handoff or model call | `tmp/emergency/complaint-orchestration-green.log` |
| Complaint and unanswered-business-question workflows, retaining blocked Review state and one fixed acknowledgment under duplicate jobs | 2 examples, 0 failures, after the unanswered case reproduced 2 examples / 1 failure | `tmp/emergency/unanswered-review-red.log`, `tmp/emergency/unanswered-review-green.log` |
| Actual adapter HTTP 402 failure acknowledgment, plus preceding workflow cases and unchanged record-only failure handler | 4 examples, 0 failures, after 3 examples / 1 failure reproduced missing acknowledgment/outbox/enqueue | `tmp/emergency/provider-failure-ack-red.log`, `tmp/emergency/provider-failure-ack-green.log` |
| Shared classifier and fixed renderer, including direct staff requests and first-person complaints | 64 examples, 0 failures: 49 routing plus 15 fixed-copy cases | `tmp/emergency/classifier-direct-human-green.log` |
| Current Review disposition replaces prior grounded-source activity metadata | 4 examples, 0 failures after 4 examples / 1 failure | `tmp/emergency/review-activity-metadata-red.log`, `tmp/emergency/review-activity-metadata-green.log` |
| Actual adapter timeout, malformed JSON, safety refusal and truncation with Swahili acknowledgment | 8 examples, 0 failures including preceding workflows | `tmp/emergency/extended-provider-green.log` |
| Ordinary greeting, persisted business evidence and Swahili acknowledgment through actual jobs, plus existing localized-question checks | 22 examples, 0 failures after individual red/green steps | `tmp/emergency/ordinary-greeting-red.log`, `tmp/emergency/ordinary-qualification-red.log`, `tmp/emergency/ordinary-acknowledgment-red.log`, `tmp/emergency/ordinary-acknowledgment-green.log` |
| Actual staff policy for a Swahili request and ordinary sales wording | 13 examples / 2 failures before the fix, then 13 / 0 | `tmp/emergency/staff-policy-red.log`, `tmp/emergency/staff-policy-green.log` |
| Committed Review/acknowledgment visible before enqueue, competing outbox workers, queue failure/recovery, and fixed-reply clarification | 14 / 2 red (only the new no-next clarification cases), then 15 / 0 including the added queue recovery control | `tmp/emergency/delivery-and-clarification-red.log`, `tmp/emergency/delivery-and-clarification-green.log` |
| Fixed Review text: English/Swahili general/complaint/refund/support copy and excluded reasons | 15 examples, 0 failures after red/green loops | `tmp/emergency/review-renderer-categories-green.log` |
| Early changed-source lint | 7 files inspected, no offenses | `tmp/emergency/lint-early-reviewed.log` |
| Combined-base actual regressions: configured-alert queue failure, unclear reply and informational imperative context/history | 5 examples, 5 failures before the corrections | `tmp/emergency/combined-review-regressions-red.log` |
| Complaint and actual HTTP 402 configured-alert queue failures | 2 examples, 0 failures; customer and operator delivery records visible from another connection before enqueue raises | `tmp/emergency/configured-alert-queue-green.log` |
| Current routing, fixed Review templates and fixed conversational replies | 84 examples, 0 failures, including direct factual/staff questions, present complaints, clarification and Sawa | `tmp/emergency/full-review-clarification-pure-green.log` |
| Exhausted expired claim with configured alert, plus live/revoked claim exclusions | 3 examples, 1 failure before the fix; six missing acknowledgment/outbox/alert assertions, both authority controls pass | `tmp/emergency/exhausted-claim-red.log` |
| Actual two-turn Swahili unknown answer | 1 example, 1 failure: evidence/provenance and next-question selection correct, fixed reply incorrectly English; minimal correction adds only `sijui` to the shared detector | `tmp/emergency/swahili-unknown-red.log` |
| Exhausted claim and both exclusions, retained R04 recovery expectation, actual Swahili unknown, actual informational imperative and later history replay | 6 examples, 0 failures on the combined current source; 30.3 seconds plus 52.32 seconds load | `tmp/emergency/final-corrections-green.log` |
| All new emergency workflows/delivery controls and the exact R09 informational-request specs | 61 examples, 1 failure; 129.4 seconds plus 20.47 seconds load. Every delivery/authority/recovery case passes; the added two-turn budget correction loses the still-unanswered business question. R09 owns the reproduced contextual-evidence dependency. | `tmp/emergency/combined-emergency-workflows.log` |
| Fourteen retained knowledge/provider/orchestration/fixed-reply/sender/crash/locking/assignment files | 238 examples, 1 failure; 469 seconds plus 20.91 seconds load. Only the older highly-qualified handoff fixture fails; evidence semantics require diagnosis. No sender, crash-recovery, shared-lead locking or assignment check failed. | `tmp/emergency/retained-coupled-verification.log` |
| Supported Swahili acknowledgment `Asante`, alongside `Sawa` | 2 examples, 1 failure solely on English reply for Asante; one shared detector token added | `tmp/emergency/swahili-thanks-red.log` |
| Final routing and fixed replies, including Asante | 85 examples, 0 failures; 1.09 seconds plus 18.77 seconds load | `tmp/emergency/final-pure-replies-green.log` |

The initial workflow and configured-alert fixes passed their allocated checks.
The final combined actual-job and delivery/race selection finished 97/1, strict
lint passed all 18 changed Ruby files, and both final source reviews found no
actionable violations. The original HQ expectation remains unresolved. The three processor Conversation
locks are inherited from the exact combined base, including R04 source `59a3bbf`.

Fresh independent GPT-5.6 Sol/Medium Standards and Spec reviews of the combined
working candidate both found one remaining P1: exhausted claims bypassed the
record-only Review service and acknowledgment path. The Spec reviewer recorded
identical hashes for all 12 reviewed files before/after review. The source freeze
was explicitly released before writing the actual regression and minimal fix.
No old Extra High reviewer was resumed. A narrowly filtered green command selected
zero examples because its alternation was escaped; that run is not acceptance
evidence. The correctly selected six-case replacement above passed.

After the exhausted-claim fix, the same fresh Standards reviewer reported no
actionable R11 findings and identical before/after hashes for all 16 changed/new
app/spec Ruby files. Root's fresh Spec reviewer also confirmed the original P1
fixed, no new findings, six stable runtime hashes and the exact R09 extractor
port. Both reviews explicitly retain the outstanding R09 budget-context defect
and are working-candidate reviews, not final release acceptance. The subsequent
budget test adds explicit absence-of-business-evidence and first-displayed-question
assertions; final source hashing must include those assertions.

The original retained handoff input (`can spend $2500`) produces no budget
observation in the current extractor; a pure probe yielded only positive problem,
urgency and decision-authority observations. That implementation behavior does not
establish whether the phrase should count as buying capacity or committed budget.
The original input and positive handoff expectations remain unchanged, and its
238/1 regression remains open. A separate positive control states `My budget is
$2500.` and passes the final actual-job verification. The coordinator is considering capacity
versus committed budget in the configurable-qualification design. No runtime
eligibility or amount parser is relaxed in this repair.

Two independent early reviewers checked only the classifier and fixed renderer.
Their reported hypothetical, negated, quoted, staff-request, greeting and language
cases were reproduced and corrected individually. Re-review also exposed a
present personal access question suppressed by the informational filter; both
"Why am I unable to access my course?" and "Why can't I access my course?" now
retain the support route. This early review does not accept the unfinished
processor integration or replace the final combined review.

All fixtures are synthetic and local. Tests deny external HTTP except explicit
controlled responses. Recorded acknowledgments are not evidence of provider
acceptance or delivery. No live provider, WhatsApp, browser, deployment or
knowledge publication action has been performed here.

The natural source-selection audit remains 6 correct ordinary selections out
of 20. This repair does not change semantic retrieval or complete full R11.

Final combined verification: 97 examples, 1 failure in 45.45 seconds plus 5.46
seconds load. The 27 emergency job cases, 15 committed-delivery cases, 4 canonical
launch-proof cases and all 24 focused R09 cases pass. The retained orchestration
file has 26 passes and its unchanged HQ failure. No case is pending or filtered
out of this final selection. The explicit-budget handoff comparison passes.

All 18 source hashes remained unchanged after the final run and both independent
final reviews. The six runtime files include the exact R09 extractor at `111345d`;
its independent Standards and Spec reviews also found no violations. Review
reports and hashes accompany this document. No old Extra High reviewer was resumed.

The local PostgreSQL and Redis services were stopped after testing. Normal commit
hooks passed at source commit `6f0b3fdd7a608014b4d5f1aa5736bf4f25b70c5d`; all 18 reviewed
Ruby hashes and all packaged artifact hashes matched afterward. The first attempt
stopped for a missing generated Husky helper, restored with the already installed
Husky installer; no hook was bypassed. See `normal-commit.txt` and `source-commit.json`.
