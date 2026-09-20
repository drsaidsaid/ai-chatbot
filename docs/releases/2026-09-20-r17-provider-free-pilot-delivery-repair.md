# R17 provider-free Pilot delivery repair evidence

## Scope

This repair carries the exact Pilot Authorization from its persisted orchestration intent onto local `conversation_reply` and `review_acknowledgment` messages. Canonical dispatch locks and verifies the persisted intent and current Pilot scope before admitting either status while the general Launch Gate remains closed. The provider-free path rejects provider usage, provider configuration, and customer-credit metadata.

No production state, canceled delivery, provider call, WhatsApp send, pilot activation, or deployment was changed.

## Checks run

- Focused provider-free and existing paid Pilot authority specs: **15 examples, 0 failures**.
- Exact Intent Processor metadata regressions for local conversation replies and review acknowledgments: **2 examples, 0 failures**.
- Focused RuboCop over all changed implementation and spec files: **7 files, no offenses**.
- `bundle exec rails zeitwerk:check`: passed (`All is good!`).

The provider-free regression set covers exact active admission through canonical eligibility and locked dispatch, review acknowledgments, missing and forged intent identity, forged local status on a persisted paid intent, mismatched review acknowledgment linkage, revoked and expired authorization, wrong Conversation scope, changed Conversation control, and provider revision drift. Local status is admitted only when it matches the persisted intent decision or acknowledgment linkage; successful local replies create no provider usage or customer-credit usage.

The broader combined historical run completed **230 examples with 5 unrelated failures**. Three failures use the `no_published_price` review reason absent from this checkout's loaded test schema enum; two canonical WhatsApp request examples timed out while truncating shared test tables. The repair-specific examples in that same run passed.
