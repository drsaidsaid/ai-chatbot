# Combined R09 acceptance — browser

Source under acceptance: `fdbab3f38c2902cda111dadf01645c2cc2a6ab33`.
This is new, uncommitted acceptance evidence; it does not amend the existing
`SHA256SUMS` manifest. `COMBINED-SHA256SUMS` records the new files.

## Isolated runtime

- Rails development server used only `POSTGRES_DATABASE=ale_r09_offers_20260911_spec`.
- The acceptance account was created locally in that otherwise empty synthetic
  database: account `203`, with a synthetic local browser user.
- Redis ran only on local loopback for this browser session.
- No provider call, customer send, deployment, or import apply occurred.

## Desktop acceptance

1. Opened **Business & offers** and created `Integration Acceptance Offer`.
2. Saved and reloaded revision 1 with qualification enabled, **Offer a sales
   call** as the useful-answer next step, and an enabled but optional **Sales
   call agreement** yes/no question that decides **Action eligibility**.
3. Opened **Leads**. Its initial Offer control showed the neutral prompt,
   `Choose an Offer to see its qualification, evidence and next action.`
4. Explicitly selected `Integration Acceptance Offer`; the URL became
   `/app/accounts/203/leads?offer_id=181&page=1`, and the selected value
   remained visible in the Leads Offer control.
5. Chose the synthetic CSV in `fixtures/r09-integration-preview.csv` and used
   **Import** only to preview. The dialog reported `1 rows: 1 new, 0 updates,
   0 errors`, displayed `Integration Preview Lead`, and was cancelled. The
   **Import Leads** apply action was never selected.

## 390 x 844 acceptance

- Offer configuration loaded with the persisted revision-1 values and the
  mobile primary navigation.
- Leads loaded with the explicit Offer still selected, the compact **Show
  filters** control, and the mobile primary navigation.
- Measured both pages: `innerWidth=390`, `clientWidth=390`, and
  `scrollWidth=390`; neither page horizontally overflowed.

## Production build

The exact build command and raw output are in
`combined-production-build.log`:

```sh
PATH="/Users/ghalyasaid/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH" \
NODE_OPTIONS="--max-old-space-size=8192" node_modules/.bin/vite build
```

It passed after transforming 5,083 modules in 2m48s. It emitted only the
existing stale `caniuse-lite` notice and Vite's large-chunk warning.
