# Resume the preserved R06 browser fixture

At the coordinator's request on 10 September 2026, the R06 Rails fixture was
stopped to release memory after acceptance. Before stopping it, `lsof` confirmed
PID `48374` exclusively listening on `127.0.0.1:3216`, and `ps` identified its
command as this worktree's `tmp/release/r06_browser_built_server.rb`. Only that
PID received `SIGTERM`. PostgreSQL on 55486, Redis on 6396, all fixture data and
the accepted browser evidence were left intact. No tests were run for shutdown.

The preserved browser database is `ale_release_r06_browser`; do not seed, reset,
truncate or reload its schema. Keep the existing local environment, launcher,
attachment storage, captured mail and `public/vite` assets. The final frontend
build is already present; neither a Vite development server nor a rebuild is
needed to resume it.

From this exact worktree, once the coordinator allocates memory/browser access:

```sh
cd '/Users/ghalyasaid/.codex/worktrees/3a8d/AI Chatbot'
set -a
. tmp/release.env
set +a
POSTGRES_DATABASE=ale_release_r06_browser VITE_RUBY_AUTO_BUILD=false VITE_RUBY_PUBLIC_OUTPUT_DIR=vite bundle exec rails runner tmp/release/r06_browser_built_server.rb > tmp/release/r06-browser-resumed.log 2>&1
```

The existing local environment file contains synthetic fixture configuration;
keep its contents outside Git. The guarded launcher refuses another database or
a non-test Rails environment. It serves the existing production assets, blocks
external network access, captures mail locally, executes only mail/socket jobs
inline and keeps other jobs on the test adapter. Its socket origins are only
the two loopback URLs below.

- Admin session: `http://localhost:3216/app/accounts/1/dashboard`.
- Member session: `http://127.0.0.1:3216/app/accounts/1/dashboard`.

Use the preserved users and memberships. The fixture includes verified Neema,
the second Business Account, scoped Conversations and the accepted private-media
attachments. Current code includes the reviewed Account lock correction; the
historical browser evidence remains tied to its recorded source checkpoint.
