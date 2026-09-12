# R09 combined integration checks

Integration parent: `58aaf41115a5d52e7566187b99defde6ba80da2a`. R09 evidence tip: `2b04aa3d0db3444b8b2735847af51cbf25265d39`; source `50df1a0433de3911e1a39e5d25ad1ef5a63b8b26`. All 21 candidate evidence hashes were verified.

Merge preserves R08 two-stage import and account cancellation, on-demand Lead detail and removal of unscoped evidence editing. R09 adds Offer filtering and stale-response/export/reconsent protection. Old tests now explicitly open the Lead after selecting an Offer, retaining their original concurrency assertions. Removed references to R08-deleted selection/evidence controls. R21 tenant-scoped provider usage counting remains inside R09 locked runtime accessor.

Combined verification: 36 Vue tests passed. Focused Rails checks cover provider usage controls, directory/update services, qualification modes, typed rules, reply context, revision and admission races; raw final output retained. Isolated test database `ale_r09_offers_20260911_spec`, local test-only encryption values, provider stubs. First Rails attempt lacked encryption settings and failed setup; corrected invocation passed. ESLint and targeted Ruby lint passed.

Final combined production build and browser confirmation remain pending the shared acceptance slot. Candidate build/browser acceptance does not substitute for this combined verification. No deployment, provider calls or customer sends.
