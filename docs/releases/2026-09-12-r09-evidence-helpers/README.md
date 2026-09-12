> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 Offer evidence and decision helpers

Before source d737cb4bf116c1b62a97764165fd67646f12b53c.
Tested source 288dc0e9652ac62dd21e1da4629ef67bfc4f61b8 passed 89 Rails examples
across ten affected files, zero failures/pending, with exact whole-tree equality.
Final source e71a73e3799a48846f068757eab57c712fc3e832 changes one block-if to
its modifier form; parsed AST equality is recorded. Tests are not relabeled as
having run on this formatting checkpoint. Final lint and manifests use that
final source; full Ruby remaining count is 41 across 91 inspected files.

Incoming observation recording moves into OfferEvidenceRecorder, called inside
the same Conversation/Offer/Contact lock scope. Message eligibility, previous
question metadata and one-match requirement, field-definition capture,
human/duplicate/newer-observation guards, creation and supersession stay ordered.
The newer-observation exists query uses the same fresh current scope/predicate;
no preloaded or locked records are replaced with pluck/exists. Offer.questions
returns an in-memory Hash array, so its key projection uses Array#pluck.

Assessment helpers preserve positive/missing/weight/rule/score/quality ordering;
qualification lookup, reasons, timestamp, save and decision creation remain
where they were. Human evidence normalization and creation helpers preserve
authorization, locking, errors, supersession, audit and reevaluation order.
QualificationEvidenceAudit now holds its contact/conversation/user/Offer context
in an instance; both internal callers are updated. Legacy and Offer audit fields,
version query, conversions, timestamps and transaction positions are retained.
No public HTTP or schema changes. The required legacy caller edit also removes
the R09-created QualificationService class-length finding.

The recorded plan, source diff, originals, exact invocations/results, formatting
proof and full source manifests support independent review. No new suppression,
full regression/build, browser, server, normal-hook commit or deployment.
