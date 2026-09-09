# R01 — canonical standalone V1 release baseline

9 September 2026 · Local acceptance complete; awaiting coordinator review and integration.

R01 repairs a reproducible upgrade failure and establishes one source, dependency,
schema and local startup baseline for R02–R18. It does not approve production
launch. [Runbook](runbook.md) · [Issue/evidence mapping](issue-evidence-map.md) ·
[ADR 0008](../../adr/0008-canonical-v1-release-and-schema-provenance.md)

## Release identity and donor decisions

| Authority | Exact identity | Disposition |
|---|---|---|
| Upstream CE reference | v4.17.0, verified upstream SHA `b34f5b71a4d7f41fa87cf2b32260e2c887817e54` | MIT retained; no enterprise root. The upstream tag resolves to the recorded SHA via `git ls-remote`; the owned import is the reproducible local checkpoint. |
| Owned CE import | `f1bf3cd0604ae610baa675061b0e76dcd49fffcd` | Committed schema checkpoint at `20260814000000`; execute all subsequent owned migrations. |
| Audited release candidate | `74d156e327e3ddb2deedd1503c6d1c04b0b1359e` | Canonical runtime chosen by the approved programme. |
| Coordinator bootstrap | `5c3bbc2f900948fcdd6729159701b9cc993b85b5` | Adds only approved documentation/evidence; no app/config/db/dependency diff from RC. |
| R01 implementation | `codex/r01-canonical-release-20260909`, based on bootstrap | Use the committed SHA delivered with this ticket. `git log -1 --format=%H -- docs/releases/2026-09-09-r01/README.md` identifies the containing R01 commit; after cherry-pick, record the coordinator's new integrated SHA too. |
| Saved root donor | `e2fa25a8db539b9fa3b45533b852d01d4766f14f` plus dirty work | Preserved. All 35 source hashes captured in the earlier audit still match; no bulk-copy of alternate Meta/provider code. |
| Browser-QA donor | `335d994fb57a6bc59f3e091fce69ac30c8d682b9` | Three donor-only commits versus 23 RC-only commits. All three are patch-equivalent to RC commits according to `git cherry`; no extra merge is needed. |

[Provenance inventory](provenance.json) records lockfile/MIT hashes and preservation
checks. All **155** files in the frozen audit and approved-plan directories remain
byte-identical to the integration bootstrap. The saved root, donor branch and
coordinator branch were not checked out or changed by R01. The read-only
`upstream-chatwoot` reference remains configured; no upstream code was imported.

## Changed behavior and schema proof

Previously, checkpoint upgrade failed in `AddNameQualificationQuestion` because
it referenced `required` and `validation_key`, which no predecessor migration
created. The regression first failed with PostgreSQL `UndefinedColumn`. Its SQL
now uses only the predecessor's columns and retains existing idempotency.

The forward reconciliation adds missing settings objects when absent and
preserves them when already present: `ai_lead_employee_offers`,
`qualification_hard_rules`, `qualification_score_ranges`, and the two question
columns. It also makes two audited defaults reproducible (`reason = 0` and
`prompt_version = ai-orchestration-v1`). Existing rows and customized question
values survive reapplication. Rollback refuses to delete potentially pre-existing
data. R09 must still implement and prove per-Offer behavior; reserved tables
alone provide no such acceptance evidence.

The final `db/schema.rb` differs from the audited schema only in migration
version. Fresh current-schema load and fresh CE-checkpoint-plus-owned-migrations
both reach **194 migration versions, 121 public tables**, version
**20260909000100**, and identical normalized schema SHA-256:

`3faa0284635ca26e702b940ec8ed82f9a1c9d24d87159d69ab8a454cdea24c81`

The comparator ignores physical declaration ordering inside a table and retains
all actual definitions and constraints. Regression tests reject changed defaults,
nullability, composite index order and migration version. The
[migration inventory](migration-set.json) lists every filename and SHA-256.

## Checks and proof limits

- Locked frontend install into a new local directory: pnpm 10.2.0; no donor dependency symlink, lockfile change or hook bypass.
- Isolated Ruby install: **381 locked gems** installed successfully; explicit libpq headers and a dependency path without spaces make native extensions reproducible.
- Fresh checkpoint upgrade and fresh current schema install both pass; schema comparison passes.
- Focused baseline/migration/canonical-request tests and comparator checks: **16 examples, 0 failures**, using the fresh Ruby install. Meta and AI HTTP in the canonical request proof are stubbed with WebMock.
- Navigation and Leads Vue suites: **14 tests pass** in the inherited UI.
- Production Vite build: **5,075 modules**, successful output. Existing Browserslist-age and large-chunk warnings remain.
- Changed Ruby files and release utilities pass RuboCop. The old Ruby smoke test's static seven-menu-string assertion was removed; the existing Vue navigation suite tests actual menu construction, and R02 owns the approved menu change.
- Rails/Puma health endpoint responds `200` with `{"status":"woot"}`. Sidekiq boots with the isolated Redis and a dedicated unused queue, then is stopped. Vite test development server starts on explicitly exported port 3091.
- In-app browser: synthetic Admin signs in, opens Leads, follows Open conversation and refreshes the persisted paused Conversation. No browser error logs were captured. The seed script creates no real messaging/AI/calendar connection or launch approval.

[Browser screenshot](evidence/synthetic-conversation.png) ·
[Accessible browser state](evidence/synthetic-conversation.txt) ·
[Recorded checks](checks.json)

The UI still shows six top-level destinations, a Chatwoot logo on login, a
hot-only default Inbox and misleading booking/proposed-step controls. These are
inherited R02/R07/R13 acceptance work, not R01 completion claims. The API-only
synthetic Inbox is test plumbing and does not expand the one-WhatsApp V1 scope.

## Approved requirements and remaining decisions

The current CONTEXT, PRD, technical design, implementation spec and scope now
agree on Inbox, Leads, Bookings, Knowledge, Settings; customer reviews in Inbox;
knowledge approvals in Knowledge; full Test Center in Settings → AI & testing;
and required basic analytics inside existing workspaces while generic CE Reports
stays hidden. One direct Meta WhatsApp connection per Business Account and fixed
Admin/Team Member roles remain. Online Profits integration is separate.

| Item | Decision or concrete outstanding input | Owner |
|---|---|---|
| Calendar provider | Google Calendar approved. Provisioned OAuth app/redirect URI, consent, target calendar and real availability/event lifecycle proof remain. | R13 |
| AI provider | Encrypted OpenAI-compatible connection, OpenRouter initially (ADR 0007). Actual model, approved spend limits and funded test credentials remain. | R10/R11/R17 |
| WhatsApp | Direct Meta through canonical CE channel. Business/WABA/phone assets, app secret, verification token, subscribed endpoint, approved templates, permitted recipients and actual test-number delivery remain. | R03/R04/R14/R18 |
| Release environment | Production host/domain/TLS, actual deployed SHA, PostgreSQL/pgvector image, Redis, encrypted secret provisioning, SMTP, object storage, monitoring and backup/restore proof remain. Existing PostgreSQL 16 staging compose is not certified by this PostgreSQL 18.6 local run. | R18 |
| Launch | Current-release evaluation, reviewer/pilot records and explicit supervised delivery approval remain. R01 grants no unattended live delivery authority. | R17/R18 |

Successors use their own ports/databases and the coordinator-reviewed integrated
commit. R01's local services are stopped after verification; disposable data and
logs remain under `tmp/r01/` for review. GitHub #18 and its parents remain open;
the coordinator reviews and integrates before changing acceptance status there.
