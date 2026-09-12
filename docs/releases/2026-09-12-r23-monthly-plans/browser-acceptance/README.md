# R23 in-app browser acceptance

Run on 2026-09-12 against isolated local database `ai_chatbot_r23_browser_2473`. All Business Accounts, credentials, payment instructions, payment references, usage records, and alerts were synthetic. No live payment, provider, Meta, or WhatsApp call was made.

## Active account — desktop

- URL: `/app/accounts/3/settings/ai-provider`
- Visible before confirmation: `Growth Synthetic`, `3 used · 7 remaining`, `30%`, renewal `2026-10-12T00:00:00.000Z`, approved 5-credit top-up, and `Scale Synthetic` upgrade.
- Clicking the top-up action created exactly one pending request and displayed `TZS 75000.0` plus `Synthetic proof only: reference R23-DEMO. No live payment.`
- The isolated platform confirmation endpoint returned confirmation id `1`, `granted_ai_replies: 5`. Repeating the identical confirmation returned the same id; database evidence remained `confirmations: 1` and `top_up_ai_replies: 5`.
- After refresh the UI showed `3 used · 12 remaining` and `20%`.

## Phone layout — 390×844

- `window.innerWidth`: `390`; `window.innerHeight`: `844`.
- `document.documentElement.scrollWidth`: `390`; `scrollWidth <= innerWidth`: `true`.
- Usage meter bounds: left `16`, right `374`, width `358`; fully inside viewport: `true`.
- The meter, renewal date, top-up, upgrade, and separately billed cost copy remained readable without horizontal overflow.

## Exhaustion account

- URL: `/app/accounts/4/settings/ai-provider`
- Visible: `1 used · 0 remaining`, `100%`, durable action-required owner alert, explicit AI pause explanation, and preserved top-up/upgrade actions.

## Renewal account

- URL: `/app/accounts/5/settings/ai-provider`
- Visible: durable action-required owner alert, renewal-due pause explanation, and `Request monthly renewal`.
- Clicking renewal created one pending manual-confirmation request showing `TZS 250000.0` and the synthetic/no-live-payment instructions.

Desktop and mobile screenshots were captured with the Codex in-app browser and are retained inline in the acceptance task transcript. The responsive viewport override was reset after capture.

## Terminal partial closure — final source

Run on 2026-09-13 against isolated local database `ai_chatbot_r23_final_2473` at final source `e0bbd23ea109f71e73f725cacf382d398ea25acd`. Before either local server started, all HTTP(S) proxy variables were pointed at refused loopback port `127.0.0.1:9`, with only `127.0.0.1,localhost` excluded. The synthetic provider connection was disabled and no worker was started. No provider, customer, payment, Meta, or WhatsApp call was made.

- Desktop before reconciliation: `R23 Synthetic`, `0 used · 2 remaining`, `33.3%`, and `1 reply credit is held while delivery reconciliation is pending. It is not billed or retried; platform review can close a proven terminal partial failure and restore the credit.`
- The finance endpoint closed usage `40` with `confirmed_partial_failure`. Two identical calls returned HTTP `200`, `partial_failure_closed`, `settled_at: null`, and the same `released_at` value (`2026-09-12T22:17:53.443Z`), demonstrating one-time idempotent release.
- Desktop after reconciliation: `0 used · 3 remaining`, `0%`, with no reconciliation-required copy. The desktop viewport was `1280×720`, document `scrollWidth` was `1280`, and the meter bounds were left `424`, right `1192`, width `768`.
- The original failed message retry returned HTTP `409` with `This delivery cannot be safely retried.` Its delivery remained `failed` with `provider_rejected` evidence.
- Database verification: `used_ai_replies: 0`, `remaining_ai_replies: 3`, `reconciliation_required_ai_replies: 0`, no settlement timestamp, no payment confirmations, and no provider-usage rows.
- At `390×844`, document `scrollWidth` was exactly `390`; the subscription section and meter were both left `16`, right `374`, width `358`. Plan, usage, renewal, top-up, and separate-charge copy remained readable without horizontal overflow.
