# Canonical standalone V1 development and test runbook

Use the coordinator-reviewed R01 commit, then the latest integrated predecessor
commit from `codex/v1-completion-20260909`. Check `git status --short` before
creating your own focused `codex/` branch. Never switch or edit the integration
worktree or copy the saved root's environment, database or dirty source.

## Runtime and dependency installation

R01 verified macOS arm64 with Ruby **3.4.4**, Bundler **2.5.16**, Node
**24.13.0**, pnpm **10.2.0**, PostgreSQL **18.6**, pgvector **0.8.6** and Redis
**8.0.1**. Rails **7.2.3.1**, Vite **6.4.2** and Vue **3.5.12** are locked.
Use the committed `Gemfile.lock` and `pnpm-lock.yaml`; do not update dependencies
as a bootstrap workaround. The existing staging compose uses PostgreSQL 16;
R18 must certify its exact target image, extensions and restore operation.

On macOS, the locked `pg` gem compiles a native extension. Ensure the PostgreSQL
client development headers are present. R01's clean install required explicitly
selecting the installed Homebrew libpq (`libpq-fe.h` was otherwise not found):

```sh
export BUNDLE_BUILD__PG=--with-pg-config=/opt/homebrew/opt/libpq/bin/pg_config
export BUNDLE_PATH="$(mktemp -d /tmp/ale-release-gems.XXXXXX)"
BUNDLE_FROZEN=true bundle install
pnpm install --frozen-lockfile
bundle check
```

The isolated `BUNDLE_PATH` must contain **no spaces**: Datadog 2.38.0 native
extension compilation fails when its libdatadog include path contains a space
(such as this repository name). Keep the exported path for all subsequent Ruby
commands; save it in the local environment file for additional terminals. Cached
`.gem` packages may be reused in the new path; never link a donor `node_modules` as the release's proof. R01
installed a new frontend directory and tested its build. `pnpm install` runs
`husky install`: verify `.husky/_/husky.sh` exists before committing. Use the
normal hook, and run explicit Ruby lint because the inherited hook masks Ruby
lint failures. Do not reproduce the audit bootstrap's one-command bypass.

The fresh pnpm install reports ignored optional package scripts for `core-js`,
`esbuild` and `vue-demi`; the locked platform binaries supported tests and build
without approval changes. Warnings about Browserslist age and large build chunks
are inherited and recorded in the proof.

## Isolated services and environment

Choose unique ports and a unique database prefix for every task. These example
values belong to an example R02 workspace; verify they are free before use.
R01 used PostgreSQL 55481, Redis 6391 and Rails 3211 and must not be shared.
PostgreSQL must provide vector, btree_gist, pg_trgm, pgcrypto and
pg_stat_statements. On this Mac the verified installation is
`/opt/homebrew/opt/postgresql@18/bin`; on another host use its equivalent.
Do not initialize or start a shared Homebrew service.

```sh
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
mkdir -p tmp/release/pg-socket tmp/release/redis
initdb -D "$PWD/tmp/release/pgdata" --username=release_local --auth=trust --encoding=UTF8 --locale=C
pg_ctl -D "$PWD/tmp/release/pgdata" -l "$PWD/tmp/release/postgres.log" \
  -o "-h 127.0.0.1 -p 55482 -k '$PWD/tmp/release/pg-socket'" start
redis-server --bind 127.0.0.1 --port 6392 --dir "$PWD/tmp/release/redis" \
  --save '' --appendonly no --daemonize yes --pidfile "$PWD/tmp/release/redis.pid" \
  --logfile "$PWD/tmp/release/redis.log"
```

Trust authentication here is for the disposable loopback-only local cluster.
Use deployed authentication and secrets only under R18's environment plan.
Create a private local environment file. Noclobber opens it exclusively before
writing configuration or generating keys; an existing file is refused:

```sh
if (
  umask 077
  set -C
  {
    cat <<'ENV'
RAILS_ENV=test
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=55482
POSTGRES_USERNAME=release_local
POSTGRES_PASSWORD=
POSTGRES_DATABASE=ale_release_r02_browser
REDIS_URL=redis://127.0.0.1:6392/0
FRONTEND_URL=http://127.0.0.1:3212
VITE_RUBY_HOST=127.0.0.1
VITE_RUBY_PORT=3092
SIDEKIQ_ALIVE_HOST=127.0.0.1
SIDEKIQ_ALIVE_PORT=7432
ENABLE_ACCOUNT_SIGNUP=false
ENABLE_TELEMETRY=false
RELEASE_ADMIN_PASSWORD=Local-synthetic-only-Pass1!
ENV
    ruby -rsecurerandom -e '%w[SECRET_KEY_BASE ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT].each { |key| puts "#{key}=#{SecureRandom.hex(32)}" }'
  } > tmp/release.env
); then
  unset DATABASE_URL REDIS_SENTINELS
  set -a
  . tmp/release.env
  set +a
else
  printf '%s\n' 'Refusing to create tmp/release.env: file exists or creation failed. Existing contents were not overwritten.' >&2
  false
fi
```

Append the chosen dependency path once, then load the file in each terminal:

```sh
printf 'BUNDLE_PATH=%s\n' "$BUNDLE_PATH" >> tmp/release.env
```

Load this file in each terminal. It contains only synthetic local secrets;
never copy production credentials or provider configuration. Keep it untracked.

## Prove fresh schema and checkpoint upgrade

Use databases that do not already exist. `db:schema:load` replaces tables; never
point these commands at a shared or populated database. `SCHEMA` selects the
input/output dump under `tmp/`, keeping `db/schema.rb` unchanged during checks.
Run from the repository root with the environment above loaded:

```sh
git show f1bf3cd0604ae610baa675061b0e76dcd49fffcd:db/schema.rb > tmp/release/checkpoint.rb
POSTGRES_DATABASE=ale_release_r02_checkpoint SCHEMA=tmp/release/checkpoint.rb \
  bundle exec rails db:create db:schema:load db:migrate db:schema:dump
cp db/schema.rb tmp/release/current.rb
POSTGRES_DATABASE=ale_release_r02_current SCHEMA=tmp/release/current.rb \
  bundle exec rails db:create db:schema:load db:migrate db:schema:dump
ruby script/release/compare_schema.rb tmp/release/checkpoint.rb tmp/release/current.rb
```

The comparator retains columns, types, defaults, nullability, composite index
order, constraints, trigger bodies and migration version. It ignores only
column/index declaration ordering inside each table. R01's two paths match at
version `20260909000100`, 194 recorded migration versions and 121 public tables.
Before loading the checkpoint, the matching baseline source must be in Git
history. Fetch the owned repository history if a shallow clone omitted it.
Do not replay pre-checkpoint CE data migrations using today's application models.

The audited schema silently included three settings tables, two question columns
and two defaults without matching migration provenance. R01 adds them through a
forward migration while preserving existing schema-loaded records. Rollback is
intentionally refused because those objects may predate the migration; use a
verified backup. Table existence is not evidence of implemented Offer behavior.

## Seed and boot the browser safely

The synthetic fixture script requires `RAILS_ENV=test`, an `ale_release_*`
database and no existing Accounts/Users. It creates one Admin, one API-only
synthetic Inbox, one Lead and one paused Conversation. It disables outbound HTTP
inside the seed process and uses test mail/job adapters. It creates no WhatsApp,
AI or calendar connection and no launch approval. This API fixture is local test
plumbing, not an extra supported V1 channel.

```sh
bundle exec rails db:create db:schema:load db:migrate
bundle exec rails runner script/release/seed_synthetic.rb
RAILS_ENV=production NODE_OPTIONS=--max-old-space-size=6144 pnpm exec vite build
VITE_RUBY_PUBLIC_OUTPUT_DIR=vite VITE_RUBY_AUTO_BUILD=false \
  bundle exec rails server -b 127.0.0.1 -p 3212 -P tmp/release/rails.pid
```

Wait for the server's listening message. In the **in-app browser**, open
`http://127.0.0.1:3212/app/login`, sign in as `release-operator@example.test`
with the synthetic password, open Leads, then Open conversation. Reload the
conversation and confirm the persisted message remains. Production-built assets
are served inside the test Rails environment, so email and application jobs use
test adapters. Keep a separate database for RSpec: its cleanup must not erase
browser fixtures. Do not run the evaluation screen with paid provider credentials
as an unconditional safe test.

For active frontend development, keep the same test database/environment and run
`pnpm exec vite --mode test` on the unique `VITE_RUBY_PORT`; run Rails without the
production asset overrides. To run the standard development worker stack, prepare
a separate synthetic development database and configure `Procfile.worktree` with
unique Rails/Vite ports before using `overmind`. Export the Vite port in the process
environment; a value only in an unexported `.env` file may leave Vite on its
shared test default 3037. The checked-in `Procfile.dev`
hardcodes Rails 3000, so do not launch it alongside other task servers unchanged.

Worker bootstrap proof can use an otherwise-unused queue:

```sh
bundle exec sidekiq -q release_boot_only -c 1
```

Stop it after the Rails/Redis boot message. Its cron definitions use the isolated
Redis. Sidekiq Alive uses the loopback host and unique health port configured
above; its defaults otherwise bind all interfaces on 7433.
Never let this worker consume shared or live delivery queues.

## Required checks for this baseline

```sh
POSTGRES_DATABASE=ale_release_r02_checkpoint bundle exec rspec \
  spec/db/migrations spec/requests/owned_baseline_smoke_spec.rb \
  spec/requests/ai_lead_employee/end_to_end_canonical_launch_proof_spec.rb \
  spec/script/release/compare_schema_spec.rb
pnpm test app/javascript/dashboard/components-next/sidebar/specs/aiLeadEmployeeNavigation.spec.js \
  app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js
bundle exec rubocop db/migrate/20260831000200_add_name_qualification_question.rb \
  db/migrate/20260909000100_reconcile_release_schema_provenance.rb script/release \
  spec/db/migrations spec/script/release spec/requests/owned_baseline_smoke_spec.rb
```

Run the relevant ticket behavior tests and build after changes. The request proof
stubs external Meta/AI HTTP; it does not certify actual delivery. The Vue suite
covers the inherited menu; R02 updates it to the approved five destinations.
Record the chosen commit with `git rev-parse HEAD`, lockfile hashes, migration
state, checks, synthetic fixture scope and remaining real-provider gaps.

## Stop and preserve

Stop Rails/Sidekiq through their own terminal sessions. Then stop only the
services created in this worktree:

```sh
pg_ctl -D "$PWD/tmp/release/pgdata" stop -m fast
redis-cli -h 127.0.0.1 -p 6392 shutdown nosave
```

Retain local logs/data for review until the coordinator accepts the ticket.
Never reset donor work, flush shared Redis, drop another task's database, close
GitHub parent issues or claim integration from a ticket task.
