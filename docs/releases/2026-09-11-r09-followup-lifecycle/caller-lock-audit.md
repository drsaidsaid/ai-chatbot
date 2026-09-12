# Implemented caller ownership

Notation follows accepted ADR0015. C/O/R are acquired before the common suffix;
all A then all F then all D then all M then all E lock in ascending ID order.

| Path | Owner and behavior | Evidence |
| --- | --- | --- |
| Scheduler | C; one complete O union; FK parents; existing A by ID; missing fresh A; F/D/M/E; immutable successor/current pointer | lineage, stale A/B and existing-budget races |
| Materializer and early exits | C/O then shared A/F/D/M/E; original F only; fresh M/D inserts; copied context | preparation, due-time, control, internal-note, stale-job cases |
| Claim | short D-only lease/count transaction | canonical once-only and crash suites |
| Authorize/greeting branches | Channel/C/O/preowned provider/member/origin R; shared suffix; atomic A admitted plus D dispatching | outcome atomic-admission check, first-increment admission races, late-authority races |
| Accept | local review C/existing unknown R then suffix; original F sent/A accepted; no new Offer check | acceptance/replacement/control races, concurrent human rejection |
| Unknown/recovery | local C/existing R then suffix; fresh missing R under C; expired dispatch remains unknown; bounded original claim recovery | unknown/late receipt, recovery/materializer, claim exhaustion, crash suites |
| Definite failure/preparation failure | suffix owner after failed preparation transaction unwinds; nonreplaceable A/F | outcome cases, preparation/replacement and A-before-D probes |
| Repair | OutboxDispatchJob uses reconcile!; A/F before D; publisher has no domain writes | old repair/replacement races, projection-only outcome case |
| Operator retry | C/O/member before suffix; ordinary human path retained; automated follow-up consumed attempts denied | canonical retry suite and Offer rejection case |
| Control/provider invalidation | inherited origin C, union O, intents R, whole batch suffix | control/provider suites and cancellation/receipt races |
| Direct opt-out creation | C/O before stop row; passes or creates one explicit batch owner | two-Conversation A-before-D regression |
| Canonical stop/reconsent | Channel/all owned C/all O before consent R; shared full batch; never resets old A | complete consent and consent concurrency suites |
| Public F/qualification cancellation | original C union/O before suffix; after-commit qualification callback uses one batch | scheduler/control/consent suites |
| Provider delivery status | recipient alias/FK work before M-only status projection; no A/F/D/E transitions | canonical delivery/webhook status suite |

Private R04 ancestry is not imported. R06 scope and original HQ input/assertion
remain unchanged. No app runtime calls a delivery-first publisher that mutates F/A.
