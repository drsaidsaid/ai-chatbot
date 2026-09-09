# R03 Spec review corrections

Correction source: `7511872fa4e5de33b72b6849aa10f2021fef2c4e`.
Tree: `eac8f8df3186e784c0cc9e0654572863e6005f83`.
The original implementation `cf83fd9b097fd62d37eff8ca5b66b5fa33543662` and
evidence commit `3e2450f878a070595976f14ffbe3f6ccb2209f64` remain ancestors.
No earlier commit was amended. GitHub #20 and parent #16 remain open for the
coordinator; the shared integration branch was not changed.

## Corrected behavior

The connection writer now checks both the saved phone number and number ID
against Meta's WABA phone identity, using the same country normalization as
incoming callback routing. A phone-only typo returns 422 and preserves the
previous number. An accepted phone-only change invalidates saved registration
and health. Callback registration is attempted again; failure cannot retain a
previous ready state. Readiness additionally requires health identity to match
the stored phone, covering previously saved mismatches as well as new writes.

Legacy raw-hash jobs and verified receipts now share `MessageStatusProjector`.
It locks and reloads the Message before applying progress, safe errors and
provider-time ordering. Late sent/failed updates cannot regress delivered/read.
An older duplicate sent update cannot move the saved timestamp backwards and
admit a stale failure. A newer failure records only a numeric provider code and
fixed recovery text; a later valid success clears those fields. Recipient
identifier synchronization remains active for legacy updates too.

The retained raw-hash path is only for already queued work. Current public HTTP
ingress still requires a verified durable receipt and enqueues its ID. This is
R03 receiving acceptance; R04 retains responsibility for outbound send claims
and ambiguous provider acceptance.

## Evidence and reproduction

- `checks.json`: **248 examples, zero failures**, including all prior R03 Ruby
  regressions, native health, five new correction examples and the retained
  360dialog incoming service suite. Eleven changed Ruby files pass lint.
- `red-green-evidence.json`: four observed failures and their passing checks.
  The original combined legacy test was split into monotonic and safe-failure
  examples during lint review; both are covered by the final 248-example run.
- `evidence-log-manifest.json`: hashes for 13 logs, with the same documented
  trailing-whitespace normalization as the original release proof.
- `runtime-source-sha256.json`: 60 changed runtime and acceptance-source files,
  now including Ruby specs. All tested hashes remained identical after normal
  commit hooks. Full base and correction Git trees pin the remaining inputs.

Use the original release README's isolated dependency and service setup, then
load the private synthetic test environment and run the saved selection:

```sh
set -a
. tmp/release.env
set +a
bundle exec ruby -rjson -e 'exec("bundle", "exec", "rspec", *JSON.parse(File.read(ARGV.fetch(0))).fetch("test_files"))' \
  docs/releases/2026-09-10-r03/review-corrections/checks.json
```

Run serially against `ale_release_r03_spec`; the concurrency examples use their
own committed fixtures and cleanup. The R03 PostgreSQL and Redis services remain
available for review. No Rails, Vite, fake-provider server or browser was restarted.

The correction changes backend behavior and the loopback provider's phone
identity fixture. Frontend/build inputs and database schema/migrations are
unchanged. Per coordinator instruction, no browser or production build rerun
was needed; the original screenshots, build and upgrade proof remain intact and
explicitly pinned to their original implementation. The frozen audits, approved
completion plan, MIT notice and enterprise source are unchanged. No live Meta,
customer, AI provider, calendar or production launch proof is claimed.
