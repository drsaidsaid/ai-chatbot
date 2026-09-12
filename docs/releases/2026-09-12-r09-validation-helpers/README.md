> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 validation and Offer-selection helpers

Source `8d1278937943e2b28317652d6f035f0be950d9e1`, before `b12a77c0f2c5867e85ca4173455f98612a4679f9`. Five production files change:
LeadFollowUp, LeadFollowUpAttempt, QualificationEvidence and the two Offer
controllers. The plan was recorded before edits. No tests changed in this group.

Existing validation clauses and selection lookup/lock statements are extracted
verbatim into helpers; the params-array change is formatting only. Persisted
guards, error order, associated/current object reads, immutable-field loops,
policy check, selected lookup before the complete ordered Offer pair lock,
selected reload/enabled check and mutation/render ordering are retained.

66 existing affected Rails examples pass, zero failures/pending. Exact source
identity before/after both Rails and full lint. The new helpers and all five
files are lint-clean. Supplementary parsed AST expansion reproduces all 18
original method bodies across the five files; its normalization removes the
helper definitions/new private marker and single-statement begin wrappers,
expands only the four explicitly named helpers, and verifies the selection
argument/return mapping. It does not replace the public regression tests.

Final Ruby inventory is63 findings across90 files; test/support paths remain
clean. The included behavior-area map separates Offer evidence/decisions21,
delivery/handoff/consent16, spoken evidence/budget clauses14, migrations5,
Leads directory2, and shared class/projection/baseline accounting5. Four of the
last group are accepted baseline categories; Account grew from177 to178 lines
and is not unchanged-magnitude debt. QualificationService class length is
R09-created. Exact accepted-source baseline evidence is retained in the earlier
UI review envelope. No new lint suppression or blanket exception.

Actual Rails invocation04:22:18–04:22:56 UTC; runtime released04:23:54 UTC. No
broader build, browser, server, normal-hook commit or deployment occurred.
Coordinator review, remaining cleanup and browser acceptance remain outstanding.
