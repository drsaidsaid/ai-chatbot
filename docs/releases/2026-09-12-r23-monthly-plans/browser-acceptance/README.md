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
