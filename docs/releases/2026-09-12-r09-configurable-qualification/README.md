# R09 configurable qualification final verification

This evidence verifies the approved R09 contract amendment against the frozen source below. The evidence commit is intentionally separate from the source commit.

## Frozen source

- Commit: `1e460bb20de3193c4376faf7b415fe081b63eee3`
- Tree: `36c3d18ba3b5e3d8324d67351e4cfe4a2217a1fd`
- Subject: `Amend R09 for configurable qualification`
- A final `git diff --exit-code` over `app`, `db`, and `spec` against the source commit was clean before this evidence was committed.

## Automated verification

- Amended selected Rails request suite: 69 examples, 0 failures. See [rails-amended-selected.log](rails-amended-selected.log).
- Delivery and configuration concurrency suite: 31 examples, 0 failures. It ran with the required isolated database name and without weakening the race guard. See [rails-delivery-concurrency.log](rails-delivery-concurrency.log).
- Offer configuration Vue suite: 1 file and 8 tests passed. See [vue-offer-configuration.log](vue-offer-configuration.log).
- Focused ESLint: 0 errors and 1 existing dynamic-i18n-key warning. See [eslint-focused.log](eslint-focused.log).
- Focused RuboCop: 20 files inspected, no offenses. See [rubocop-focused.log](rubocop-focused.log).
- The production Vite build had already passed on this exact frozen source in 3 minutes 49 seconds, with only the known caniuse database and chunk-size warnings. It was not rerun after source freeze, as requested.
- The reversible assessment migration had already passed a direct down/up cycle on this exact frozen source.

## Browser acceptance

Fresh acceptance was completed in the Codex in-app browser against the local application and isolated verification database. It covered all amended configuration choices, owner-authored question metadata, the requirement dimension, and save/reload persistence. A follow-up pass used the browser viewport capability at 390 × 844, verified editing and persistence at phone width, and confirmed no horizontal overflow. See [browser-acceptance.md](browser-acceptance.md).

## Integrity

SHA-256 checksums for the evidence files are recorded in [manifest.sha256](manifest.sha256). The unrelated untracked `graft/` directory was excluded.
