# R21 acceptance evidence

## Scope and isolation

- Source baseline: `e97b1f8bed27824068cc9ae92bccf61cb6de661f`.
- PostgreSQL: disposable database `ale_release_r21_browser` on `127.0.0.1:55535`.
- Redis: disposable instance on `127.0.0.1:6435`, database 1.
- Rails browser server: `127.0.0.1:3215` with production Vite assets.
- Fixtures use placeholder provider names, models and credentials. No provider or
  WhatsApp request was permitted or made.

## Automated verification

- The complete R21-changed Rails spec set ran against final runtime source
  `e8c974ec`: 85 examples, 0 failures. The retained log includes provider
  control, usage isolation, platform authorization, delivery, and end-to-end
  coverage.
- Vue managed-service page, navigation and settings layout coverage: 12 tests,
  0 failures.
- Focused RuboCop: 16 files, no offenses.
- Focused ESLint: no errors; warnings are pre-existing formatting warnings in
  the settings shell outside the changed label.
- Full production Vite build at `6a1dd7e3`: passed (5,078 modules
  transformed). A retained source-equivalence check proves no frontend source
  changed between that build and final runtime source `e8c974ec`; the retained
  Vite manifest SHA-256 is unchanged.
- Route inspection and `git diff --check`: passed.

## Browser acceptance

The in-app browser was run against final runtime source `e8c974ec`, the
disposable release database, and production assets at both 1280 x 720 and
390 x 844.

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
- At 390 x 844, the card measured 358 pixels wide with 16-pixel side margins,
  body scroll width equaled the viewport width, and the settings selector plus
  mobile bottom navigation were visible. There was no horizontal overflow.
- Final desktop, phone, and Team Member browser logs contained no errors or
  warnings.

Exact DOM observations are retained in
[`evidence/browser-observations.json`](evidence/browser-observations.json).
