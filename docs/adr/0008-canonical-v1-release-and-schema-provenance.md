---
status: accepted
---

# Reproduce the audited standalone release before completing V1

R01 (#18), 9 September 2026. The owner approved R01–R18, the five-item
navigation and Google Calendar as the first provider. ADRs 0002–0007 remain
in force. This decision supersedes older branch, navigation and provider-choice
statements, not the frozen audit evidence.

## Release authority

The audited runtime is `74d156e327e3ddb2deedd1503c6d1c04b0b1359e`.
The coordinator's bootstrap `5c3bbc2f900948fcdd6729159701b9cc993b85b5`
adds documentation only. R01 starts there on `codex/r01-canonical-release-20260909`.
After review, only the coordinator integrates successor commits on
`codex/v1-completion-20260909`. A branch name or historical Done note is not a
release identity: each proof records the exact commit and its dependencies,
migrations, environment and limitations.

The saved root at `e2fa25a8db539b9fa3b45533b852d01d4766f14f` and the
`335d994fb57a6bc59f3e091fce69ac30c8d682b9` browser-QA branch are donors,
not release authorities. Keep their dirty files and refs intact; no bulk merge
or copy of their alternate Meta or plaintext settings-provider paths is allowed.
Frozen source snapshots and screenshots remain byte-identical. Retain the
Community Edition v4.17.0 MIT notice and exclude `enterprise/`.

## Reproducible schema

The supported upgrade baseline is the schema from the owned CE import
`f1bf3cd0604ae610baa675061b0e76dcd49fffcd`, version `20260814000000`.
Load that checkpoint, then execute every later owned migration. CE historical
migrations before that checkpoint are retained, but replaying years of old
data migrations with today's models is not the supported installation path.
Fresh installs load the current schema and run outstanding migrations.

R01 reproduced a failure at `20260831000200`: it inserts `required` and
`validation_key`, columns absent from all preceding migrations. Commit
`3e9819fd1e03da439290c515ef89dff15c7f8dc5` added these columns and the
`ai_lead_employee_offers`, `qualification_hard_rules` and
`qualification_score_ranges` tables to the schema without a migration. The same comparison found schema-only defaults for
`human_review_requests.reason` and `ai_lead_employee_evaluation_runs.prompt_version`;
the forward reconciliation preserves the audited defaults for both paths.

Correct the historical name data migration to use only its predecessor's
columns. Add a forward migration for the missing schema objects, skipping
objects already present in RC-schema installations and preserving their data.
Do not drop donor tables or pretend their existence implements per-Offer
qualification. R09 owns that behavior. The reconciliation cannot be rolled
back by deleting tables that may already contain operator data; restore a
verified backup when reversing this baseline decision.

Prove checkpoint-plus-migrations and current-schema-plus-migrations converge
on the same schema. Keep dependency lockfiles unchanged and prove the build
with a newly installed frontend dependency directory. Use isolated local
PostgreSQL, Redis, browser ports and synthetic records; no provider credentials
or worker with live delivery authority are needed for baseline proof.

## Product scope

The main menu is Inbox, Leads, Bookings, Knowledge, Settings. On phones use
Inbox, Leads, Bookings, More, with Knowledge and Settings inside More.
Customer Review Requests belong in Inbox; reusable knowledge approvals belong
in Knowledge. Full Test Center belongs in Settings → AI & testing.
Basic business metrics remain required within Leads and relevant workspaces;
the generic CE reports suite stays hidden. R02 and R16 implement these decisions.

V1 has one direct Meta WhatsApp connection per Business Account and the fixed
Admin/Team Member roles. Google Calendar is selected; OAuth provisioning and
real availability/event acceptance belong to R13. OpenRouter remains the
initial encrypted OpenAI-compatible AI Provider Connection (ADR 0007).
Online Profits identity, purchases, access, memberships and journey integration
are separate work. Production hosting, secrets, provider assets, backup/restore
and supervised pilot proof belong to R18; local boot does not approve launch.
