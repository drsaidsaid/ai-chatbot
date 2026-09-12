# R21 acceptance evidence

## Scope and isolation

- Source baseline: `e97b1f8bed27824068cc9ae92bccf61cb6de661f`.
- PostgreSQL: disposable database `ale_release_r21_browser` on `127.0.0.1:55535`.
- Redis: disposable instance on `127.0.0.1:6435`, database 1.
- Rails browser server: `127.0.0.1:3215` with production Vite assets.
- Fixtures use placeholder provider names, models and credentials. No provider or
  WhatsApp request was permitted or made.

## Automated verification

- Rails provider control, usage, platform authorization, delivery and
  end-to-end request coverage: 96 examples, 0 failures. This includes a
  focused post-review regression proving a mismatched legacy usage row cannot
  consume another account's runtime allowance.
- Vue managed-service page, navigation and settings layout coverage: 12 tests,
  0 failures.
- Focused RuboCop: 16 files, no offenses.
- Focused ESLint: no errors; warnings are pre-existing formatting warnings in
  the settings shell outside the changed label.
- Full production Vite build: passed (5,078 modules transformed).
- Route inspection and `git diff --check`: passed.

## Browser acceptance

The in-app browser was run against the disposable release database and
production assets.

- A Business Account admin saw `Managed AI service`, service `Active`,
  readiness `Healthy`, usage `1 / 25`, `24 requests remain`, and an EAT reset
  label.
- The managed-service view contained no provider name, model identifier, API
  key language, provider form, or provider action button. The only select on
  the rendered settings page was the global settings-section navigation.
- A Team Member navigating directly to the provider-settings URL was redirected
  to Inbox. The member navigation had no Settings link and the rendered page
  contained no provider-identifying text.
- An unauthenticated platform endpoint request returned HTTP 401 with only
  `Invalid access_token`. Permitted and unpermitted Platform App paths are also
  covered by request specs using synthetic tokens.
- Browser logs contained no errors. One informational client-storage cleanup
  message was observed.

The in-app browser surface exposes a fixed 1280 x 720 viewport. Its capability
inventory offers only page assets and WebMCP, creating a tab with width/height
options remained 1280 x 720, and page-level `window.resizeTo` is unavailable.
The responsive implementation therefore remains covered by the component's
single-column base layout and `sm:grid-cols-2` enhancement rather than a
separately captured phone-browser run.
