> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 directory booking and sort boundaries: RED

After exact becb6fc reader49 reproduction and before production edits, ten new
request examples expose Offer booking-filter leakage and incorrect neutral sort
metadata. First10/10 included a fixture issue: extra Contacts lacked phone/email
and did not meet the existing resolved-Contact directory scope. After adding
synthetic phone numbers, all10/10 fail on intended booking predicates or metadata.
The first fixture and both raw logs are retained. The corrected spec is frozen
with the complete repository using automatic inventory. This capture follows the
RED run with no intervening production or corrected-spec changes. No claim of a
pre-run whole-tree equality check is made for this RED run.
