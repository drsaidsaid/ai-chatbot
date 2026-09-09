# R06 refresh onto accepted R03

Status: combined regression, lint, schema comparisons and production build passed. Browser acceptance remains pending the owner's existing Mac-unlock
request. This is a feature-branch merge, not R06 promotion into shared integration.

Merge commit: `d4b2922a89f1d5696c736274141e7c2031245e48`. Normal hooks passed; all 116 runtime
source hashes remained unchanged. The acceptance-source manifest records all
55 backend/frontend files used by the saved selections.

## Parents and merge review

- Prior R06 tip: `e8b5b5da7fb6722d6b0c8e40c74dc296f708b610`.
- Exact accepted R03 tip: `f2b184e1c332f0bf68c31dec460f7e5599657a72`.
- Original R01/R02 base: `5577a37ddae5f6d08b33b0b33aefe6d933d7003c`.
- Merge completed automatically with no conflicts; both histories are retained.
  No shared integration worktree or R04 work was changed.

Review confirmed that the R03 direct WhatsApp Settings route, encrypted safe
credentials, Admin-only connection/health/registration, phone identity validation
and shared `MessageStatusProjector` remain intact. The R06 member Inbox index/show
still choose the minimal transport payload and resolve currently assigned
Conversations. Native media/session and queued access checks remain intact.
ADRs 0009 and 0010 remain separate.

## Test fixture reconciliation

The first combined run completed 493 examples with six failures. One R06 fixture
omitted the Meta phone identity now required by R03. Five native sender tests used
unsaved attachments, which cannot receive R06's signed attachment capability.
The production MessageBuilder autosaves attachments before after-commit delivery.

The fixtures now provide a matching synthetic phone identity and persist their
attachments. Provider request matchers additionally require `/whatsapp/media/`
for image/document/audio/voice/BSUID sends. No production runtime logic was changed
to accommodate the fixtures. The affected media/provider run passed 35 examples.

## Combined verification

- Full serial regression: **493 examples, zero failures** (1m58.08s, 6.27s load).
  The exact 48-file/location selection is stored in `test-selection.json`.
- Frontend: 39 tests passed across seven R06/R03 invitation, Lead, cockpit,
  navigation, socket invalidation, Settings-layout and connection-page files.
- Production Vite build: 5,078 modules, 3m36s. The single build completed and its
  allocated slot was released. Browserslist-age and chunk-size warnings remain.
- Ruby lint: 131 changed non-schema/migration Ruby files, no offenses. The two
  reconciled fixture files also passed lint after formatting.
- Frontend lint: zero errors, 36 inherited formatting/i18n warnings.
- Both isolated R06 databases migrated through `20260910000304`. Their complete
  dumps, including triggers, match the accepted R03 schema. Normalized hash:
  `438329e761330cb7e9654cfcd78f22a6b0337873e1a881770fe2d7aafbfb9489`.
  R03's accepted schema and migration files remain unchanged by R06.

No new browser attempt, screenshot, live provider delivery or launch acceptance
is claimed. R03's prior browser evidence stays pinned to its own implementation.
The R06 synthetic fixture is retained for the combined in-app acceptance after
owner unlock; do not treat automated checks as that acceptance.

## Reproduce

Use the private R06 environment and isolated test database from the parent
README. The concurrency cases clean committed fixtures, so run the selection
serially and never against the browser fixture database. The seven frontend
paths are also recorded in `checks.json`; pass them directly to `pnpm test`
because the package script already supplies the run flags.

```sh
set -a
. tmp/release.env
set +a
POSTGRES_DATABASE=ale_release_r06_spec bundle exec ruby -rjson -e 'exec("bundle", "exec", "rspec", *JSON.parse(File.read(ARGV.fetch(0))))' docs/releases/2026-09-10-r06/integration-refresh/test-selection.json
RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=6144 pnpm exec vite build
```
