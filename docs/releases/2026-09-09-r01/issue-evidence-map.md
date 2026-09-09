# Historical issues and current acceptance evidence

Read from GitHub on 9 September 2026. #18 had no comments; its published body
matches the local R01 ticket. The broad parent issues #7–#17 are all **open**;
none was edited or closed. Their checkboxes and historical local Done notes do
not imply R01–R18 completion. The current glossary uses **Low Qualified**, even
where older issue wording differs.

| Existing issue | Historical local claim | Current evidence and boundary | Completion tickets |
|---|---|---|---|
| [#7 V1 spec](https://github.com/drsaidsaid/ai-chatbot/issues/7) | 000–019 marked Done in the historical index | Requirements now bind to ADR 0008 and this release. No production deployment or paid provider proof here. | R10, R18; umbrella for all slices |
| [#8 Qualification](https://github.com/drsaidsaid/ai-chatbot/issues/8) | 007 recovery, 016 settings Done | R01 fixes the migration predecessor and records schema-only settings provenance. Audit still finds unsupported qualification evidence and absent per-Offer authority. | R09 |
| [#9 Handoff and alerts](https://github.com/drsaidsaid/ai-chatbot/issues/9) | 007, 017, 018 Done | Source exists; audit identifies handoff/recipient/routing gaps. R01 does not send alerts or certify handoff policy. Current corrections govern exceptions to older qualification-only handoff wording. | R14 |
| [#10 Follow-up and opt-out](https://github.com/drsaidsaid/ai-chatbot/issues/10) | 008 recovery, 018 settings Done | Audit identifies narrow opt-out detection and missing final delivery checks. No live follow-up was enabled in R01. | R05, R15 |
| [#11 CE baseline and access](https://github.com/drsaidsaid/ai-chatbot/issues/11) | 000 Done | Fresh schema/checkpoint convergence, MIT/CE exclusion, Rails/Redis/worker boot, sign-in, recovery/invitation and tenant-scope request checks now re-proven locally. Older seven-area menu in parent is superseded by approved five-area navigation; R02 must implement it. | R01, R02, R06 |
| [#12 Booking](https://github.com/drsaidsaid/ai-chatbot/issues/12) | 008 recovery, 013 workspace, 017 settings Done | Audit finds calendar stub and availability/lifecycle gaps. Google Calendar is approved; OAuth and real calendar acceptance remain unproven. | R13 |
| [#13 Dashboard/team access](https://github.com/drsaidsaid/ai-chatbot/issues/13) | 010–012, 017, 019 Done | Synthetic Leads → persisted Conversation works in the in-app browser. Current UI retains wrong/ineffective controls and old navigation; fixed role scope and trustworthy metrics require their own tests. | R02, R06, R07, R08, R16 |
| [#14 Evaluation and launch gate](https://github.com/drsaidsaid/ai-chatbot/issues/14) | 009, 015 Done | Audit finds older reviewed passes can mask newer failures and weak release binding. R01 creates no launch approval; existing canonical request proof uses stubbed external HTTP. | R17 |
| [#15 Approved answers/media](https://github.com/drsaidsaid/ai-chatbot/issues/15) | 004, 014 Done | Existing grounded boundary is retained; audit records source relevance/context/claim gaps. No real AI-provider response or customer message is part of R01 proof. | R11 |
| [#16 Meta round trip/control](https://github.com/drsaidsaid/ai-chatbot/issues/16) | 001, 002, 005, 006, 019 Done | Four canonical launch request examples pass with WebMock at the Meta/AI boundary. They are local regression evidence; raw receipt durability, send ownership, consent/window recovery and real test-number delivery remain acceptance work. | R03, R04, R07 |
| [#17 Review and knowledge approval](https://github.com/drsaidsaid/ai-chatbot/issues/17) | 004, 014 Done | Source and UI exist; the audit confirms customer work and knowledge approval are mixed. Approved navigation assigns them to Inbox and Knowledge respectively. | R12 |

The [historical index](../../issues/README.md) links individual 000–019 records.
The [active index](../../issues/v1-completion-20260909/README.md) links every
published #18–#35 issue with blockers. R01 is locally complete only after the
checks in this release record; successor work starts from its coordinator-reviewed
integration commit, not from a historical Done note or an unreviewed donor.

## Evidence sources

- [Frozen UI audit](../../ui-ux-audit/2026-09-09/README.md): synthetic browser evidence at `74d156e3`.
- [Frozen functional audit](../../integration-audit/2026-09-09/detailed-audit.md): static and offline findings, not a production test.
- [Historical final gate](../../issues/019-final-visual-parity-and-end-to-end-browser-gate.md): reported 64 focused Rails, 4 settings and 36 Vue checks; not rerun wholesale here.
- [Historical launch proof](../../launch_proofs/006-end-to-end-canonical-launch-proof.md): an earlier fixed point with stubbed providers.
- [Current R01 proof](README.md): exact dependencies, migration comparison, synthetic browser and focused regression checks.
