# OPU source correction preserves independent qualification

Root reviewed candidate `f90fc731fb8816c3a51b24597f73e11f87dbc0f6` against its parent and applied its two-file delta to integrated `ccb13a47228645203d5fe1bab1a4ec09fff5c5e4`.

The actual staging dry-run exposed legacy source ownership resetting enabled qualification to not-configured despite a newer independently saved seven-question/four-group Offer. The repair retains the current mode when independent qualification survives source-field removal. Empty source-only configurations still reset to their prior baseline. The source publication guard remains unchanged.

Spec review: no actionable findings. Standards review: no violations or meaningful smell findings. Root canonical request suite: 69 examples, 0 failures (19.94 seconds), including the new regression. Staged diff check passed. No frontend/runtime dependency or migration changes; existing accepted frontend assets remain applicable.

At acceptance the actual staging Offer is revision3 with published quote-required commercial revision1. Source1 version2 remains unpublished; the corrected source preview must be rerun after deployment. No provider calls, live sends or pilot authorization were activated. Full R17/R18 remain open.
