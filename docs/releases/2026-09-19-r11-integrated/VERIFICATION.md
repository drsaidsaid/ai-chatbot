# R11 integrated verification — 19 September 2026

Status: local integrated-candidate verification passed; normal commit/push pending. Not deployed or live-verified.

The canonical candidate is based on `582227e9b16153de1182e7a1dfcdc980dfc1c910`, with pending merge of `23397c9cb29bbd020c13fd86ccd56ac7bcfb8c44`. It also includes reviewed corrections from `80b3b92145f84d8eafbe480072d4a135c3405953`, `d56e27602cfa5ecd9c28b86543c0b5ccfcc0f836` `606b980a1318982bd0cf0e38fbfdc29bd45ab5d6` and `43e278c448a1385c8881be6167477d8eb455852b`.

## Integration correction

R11's deterministic Review acknowledgement must remain deliverable after a failed or rejected provider answer releases its reserved customer usage. The merge now attaches usage authority only to an actual provider response. Root reproduced two failures before the correction and verified the two nonbillable acknowledgements plus the successful billable answer path afterward. No customer credit is charged for the deterministic fallback. The R23 allowance and R26 template eligibility boundaries remain intact.

## Automated evidence

- Root: 315 focused Rails examples passed in the exact owned database `r11_integrated_20260919_test` (`/tmp/r11-integrated-focused-20260919.log`).
- Cross-ticket run: 54 examples passed; seven fixture/expectation failures were diagnosed. The source-concurrency fixtures lacked the integrated subscription prerequisite; accounting expectations incorrectly prohibited the newly required Review acknowledgement. Corrected assertions retain provider-once, credit release, source locking and no persisted provider answer. Both independent reviewers cleared them. The two affected files then passed all eight examples (`/tmp/r11-integrated-cross-rerun-20260919.log`).
- Root affected Vue coverage: 16 unchanged tests passed and the final Test Center suite passed all 10 tests (`/tmp/r11-evidence-ui-test-20260919.log`).
- Root integration Ruby lint: five files, no offenses; affected JavaScript/Vue lint: seven files, no errors.
- First integrated production build passed in 1m15s; manifest contained 232 entries with zero missing assets. Final production rebuild passed in 1m1s (`/tmp/r11-final-i18n-build-20260919.log`); all manifest assets exist.
- Worker API-only sandbox regression reproduced an attempted Meta template request before the fix. The corrected full SandboxRunner suite passed eight examples. Both root reviews cleared the two-file correction.

## Actual in-app browser evidence

Root used the Codex in-app browser, never an external-browser result, on synthetic `r11_browser_test`. The Rails server binds only localhost; WebMock blocks external connections, provider responses are deterministic stubs, and jobs/mail use test adapters.

- Document 1, Synthetic onboarding guide, changed from Draft to Published through the UI.
- Try this answer navigated to the existing Test Center with `knowledge_document_id=1` and the correct document title.
- Initial contextual run exposed the real fallback-inbox callback bug. WebMock blocked Meta before network access. The corrected fallback is a tenant-owned, transaction-scoped API channel; normal WhatsApp callbacks remain unchanged.
- Run 1 answered from the published document; 1/1 automated checks passed.
- Run 2 answered the approved AI-employee question without a qualification prompt, with continue-AI and booking/follow-up ineligible; 6/6 checks passed.
- Run 3 clarified an ambiguous question, then acknowledged the missing approved answer and recorded Review; 9/9 checks passed.
- These runs still require human grading, displayed as Needs Review. That evaluation status is distinct from a simulated conversation Review Request.
- Browser inspection caught misleading source, Offer, model and Review-reason labels. The reviewed UI correction now reads persisted evidence; final built-browser retest passed: Sources names the synthetic document, absent Offer/channel show None, model shows synthetic/r11-browser, and Review path shows No Approved Knowledge. The phone viewport was 390×844 with body/page width 390 and no horizontal overflow; viewport reset and test tab closed.
- Read-only persistence check after the simulations: zero Messages, WhatsApp channels, customer reply usages and Outbox events. Two stubbed provider evaluation ledger entries remain; no paid provider comparison or live send occurred.

Earlier evidence remains historical, including the documented shared-test-database cleanup incident. This verification used only explicitly owned databases and did not repeat that cleanup.

Final browser server stopped after verification. No production deployment or live WhatsApp test is claimed.

After the final assertion-helper and sandbox changes, root reran the two acknowledgement regressions, accounting-failure file and complete SandboxRunner file: 15 examples, zero failures (`/tmp/r11-final-backend-20260919.log`).
