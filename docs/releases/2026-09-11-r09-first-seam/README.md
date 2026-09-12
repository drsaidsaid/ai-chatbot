# R09 first bounded public Offer path

Date: 2026-09-11. This is an intermediate result, **not full R09 acceptance**.

Base: `9a834e756347822d4ae5af15f268a5e8751fc852`.
Branch: `codex/r09-offer-qualification-20260911`.
Worktree: `/Users/ghalyasaid/.codex/worktrees/f529/r09-offer-qualification`.
The source is uncommitted; [sources.sha256](sources.sha256) identifies the runtime,
migration/schema and request spec used for this result.

## Observed result

The original five request/inbound specs failed at the missing public Offer route
on the accepted baseline: **5 examples, 5 failures**, preserved in
[public-path-red.txt](evidence/public-path-red.txt).

After source implementation and successful
[migration 20260911001400](evidence/offer-migration.txt), the same specs passed:
**5 examples, 0 failures**, preserved in
[public-path-green.txt](evidence/public-path-green.txt). No assertion or test input
was changed between those runs. RSpec reported 5.22 seconds of examples and
18.05 seconds loading for green. The log includes inherited Rails enum warnings.

Command, using the private synthetic environment wrapper under `tmp/r09`:

```sh
python3 tmp/r09/run.py two-offer-first-green-attempt bundle exec rspec \
  spec/requests/ai_lead_employee/offer_qualification_spec.rb --format progress
```

The five examples establish:

- Two Offers round-trip independent TZS minimums through create/read/update HTTP
  in major units (`500000.00` and `200000.00`).
- An explicitly empty question list stays empty after reload.
- A stale configuration revision receives a conflict and does not overwrite a
  newer edit.
- A member and a foreign-account administrator cannot write configuration.
- Two Conversations for one Lead select different Offers through HTTP. Actual
  orchestration processes `Bajeti yangu ni TZS 600000.` for Offer A, persists
  positive TZS evidence with its source message and configuration revision,
  and asks the missing problem question. Offer B does not inherit A's budget
  and asks its own budget question.

## Scope and limitations

This is a narrow API/storage/orchestration result. It does not establish the
complete scoring/rule matrix, custom typed answer extraction, historical replay,
human correction behavior, configuration invalidation at final dispatch,
cross-Offer reader/access behavior, migrations from every legacy state, or the
Vue settings/Lead/Conversation path. Rule editing currently rejects nonempty
rules; the incomplete preparation branch must not be deployed.

Only three reviewed generic parser source files were copied deliberately from
`111345dc2c58ed2e8f467f2ee1b1ce8cd77ec7e6`; no private ancestry or old processor was
imported. The current IntentProcessor diff adds only Offer identity to the
qualification payload. The accepted R10 provider/allowance fences are unchanged.
No concurrent-lock compatibility claim is made for the new path.

The retained `can spend $2500` Highly Qualified regression remains unchanged.
ADR 0014 records its approved capacity-versus-commitment interpretation, but the
new capacity/allocation contrast specs have not been executed or implemented in
this bounded slice. They were not needed for the explicit TZS budget seam.

The isolated database is `ale_r09_offers_20260911_spec`, on loopback PostgreSQL
55519; Redis used loopback 6421. Both services were stopped and both ports were
confirmed without listeners after green. The coordinator was told the heavy
interval is released. There was no dependency installation, build, hook, browser,
live provider/WhatsApp send, or deployment during this interval. No full lint,
review or commit acceptance is claimed.
