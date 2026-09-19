# R20 integrated acceptance — 19 September 2026

Candidate `cbc3fccc` is combined with accepted R07/R11 baseline `33df52440a4f09c417e382d60926291dcba6e638`. Status: integrated local acceptance passed; evidence included in normal integration commit. Not deployed or live verified.

The schema conflict preserves the later September 13 schema version, conversation resume boundary and outbox receipts, alongside all commercial tables and composite tenant constraints. Independent combined review cleared schema, routes and locale preservation.

## Upgrade and backend checks

Fresh owned `ale_r20_integrated_20260919_spec` loaded the exact baseline schema. Its schema-load ledger included the lower-numbered R20 migration without its tables; only that version was removed after asserting the exact database and absent commercial table. Normal migration added the pricing schema. A pre-upgrade synthetic Account survived; both commercial terms and outbox receipts exist. Generated schema differs only in PostgreSQL text-cast rendering and table/FK ordering, not behavior.

Combined focused backend run: 62 examples, zero failures, including pricing authority, tenant database constraints, proposals, promotion eligibility, stale final send and conversation controls. Logs: `/tmp/r20-integrated-schema.log`, `/tmp/r20-integrated-migrate.log`, `/tmp/r20-integrated-spec.log`.

## Actual browser evidence

Root used only the Codex in-app browser with guarded synthetic account 3 on loopback and external requests blocked. Created an Offer, saved TZS1250 draft without publishing, explicitly published and verified amount/conditions/link. Saving TZS1500 draft preserved live1250. An Offer-scoped authored document with900 generated conflict review; approval changed draft only, then explicit publication changed live900. Quote-required published with no invented amount; reload preserved state. At390x844 body/page widths were390.

Browser found a stale preview after publication. The candidate correction passed a red/green regression and12 component tests; root retested publication clearing old preview and fresh preview using updated conditions. Copy now states preview uses current published price. Tabs closed and viewport reset; owned server/Redis stopped. No paid provider or live customer send.

Candidate broader evidence and build logs remain in `docs/releases/2026-09-19-r20/`.

Combined Offer settings and Conversation Cockpit frontend suites passed 35 tests, zero failures (`/tmp/r20-integrated-vue.log`).

Final integrated production build passed;232 manifest entries, no missing assets. Log `/tmp/r20-integrated-build.log`. Source/test hashes recorded separately and verified unchanged before commit.
