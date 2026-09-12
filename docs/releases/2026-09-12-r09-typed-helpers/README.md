> Checkpoint packaging: saved Ruby evidence is now `.rb.txt` with unchanged bytes. Other SHA manifests in this historical package describe original paths/content and must be checked in a restored scratch copy, not directly here. `packaged-files.sha256` describes the current packaged files. See [the path map and restoration instructions](../2026-09-12-r09-reviewed-checkpoint/README.md). Proof scripts are not run in place.

# R09 typed-answer and rule helper extraction

Source `0c51243eb38cabcb38f3ae53f358863b11104775`, before `dc4da70f482b820bca0d2c7a700c62814986541a`. Only OfferTypedAnswer and OfferRules change in this source diff. The bounded production plan was recorded before edits.

Existing number, money, boolean, text, effect validation, operator compatibility and comparison branches are extracted into named helpers. Existing public methods remain public; new class helpers are private. No query, lock, transaction or persistence change.

39 existing affected request scenarios pass with exact source identity before/after. Both edited files pass lint. Supplementary differential comparison against the frozen originals matches all 2,376 cases: 576 typed observations, 900 normalizations, 720 effect validations and 180 rule outcomes. Comparisons include returned structures and exact exception class/message, false versus nil, polarity, supported currency precision and invalid values. This finite comparison supplements the public request tests; it is not exhaustive proof for arbitrary custom Ruby objects.

The full changed-file Ruby lint inventory and exact-source proof are included; accepted baseline findings remain separately documented in the prior UI evidence. No lint rules were suppressed. Source manifests cover every blob and every changed runtime/test path. This remains uncommitted development work pending coordinator review and browser acceptance.
