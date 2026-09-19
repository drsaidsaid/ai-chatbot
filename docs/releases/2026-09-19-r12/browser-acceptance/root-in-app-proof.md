# Root-performed in-app browser proof

Date: 2026-09-19

The root coordinator performed these checks in the Codex in-app browser against the guarded local synthetic environment. No external browser, worker, provider connection, paid model call, calendar connection, payment data, or customer data was used.

- Review 1 legacy link redirected to its canonical conversation. A public resolution persisted as pending delivery after reload.
- Switching to Review 2 removed Review 1's `review_id` from the route.
- Review 2 saved a private note. After legacy-link reload, its reusable-answer field was blank.
- A separately entered public answer created Knowledge Item 2 as a draft. The administrator approved it in the Knowledge UI, and its content did not contain the private note.
- Standalone Lead Handoff 1 accepted poor-fit configuration feedback without a fabricated Review Request.
- The pending feedback appeared in the administrator's real Inbox **Needs review** queue on desktop and at 390 × 844. At mobile width, `innerWidth`, `clientWidth`, and `scrollWidth` were all 390.
- The feedback card displayed the localized qualification, score, and reason summary without raw JSON. Marking it reviewed removed it from the pending queue and did not change any Offer rule.
- Final database evidence retained Offer configuration version 1 and SHA-256 `ee7485b8f042f0aa5de4041e676bc5e7b58cfcd952079912de254a9d080332e7`.
- A deterministic `KnowledgeAnswerService` lookup returned the newly approved Knowledge Item 2, with `refused=false` and `private_text_present=false`.

The final two-reason display bound was verified afterward by the focused component regression using three input reasons and asserting that the third is absent.
