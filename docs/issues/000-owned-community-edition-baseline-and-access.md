# Owned Community Edition Baseline and Access

## What to build

Replace the prototype runtime with the pinned Chatwoot Community Edition source
as the owned AI Lead Employee application foundation. Preserve the MIT notice,
exclude Enterprise code, preserve the Community Edition Rails/Vue technology
stack and product feel, establish the owned product branding and V1 navigation,
and make invite-only Human Operator access tenant-safe before messaging features
are built. The result must feel like one Community Edition-derived product with
owned AI Lead Employee capabilities, not a separate prototype shell patched onto
the side.

## Acceptance criteria

- [x] The pinned Community Edition `v4.17.0` source runs from the owned repository root with its MIT notice retained and no Enterprise code imported.
- [x] The owned Rails, Vue, PostgreSQL, Redis, and background-worker stack boots locally using application-owned configuration only.
- [x] The operator experience keeps the Community Edition dashboard shell, inbox layout, component conventions, Tailwind styling approach, and interaction model.
- [x] The product is branded AI Lead Employee and does not require a Chatwoot account, cloud API token, or webhook secret.
- [x] An initial admin can be provisioned, sign in through owned invite-only access, recover a password, and invite a team member.
- [x] Server-side membership resolution prevents a user, request, job, or query from accessing another Business Account.
- [x] V1 navigation exposes only Inbox, Hot Leads, Leads, Reviews, Knowledge, Bookings, and Settings as native-feeling Community Edition dashboard surfaces; unrelated Community Edition surfaces are hidden.
- [x] The `upstream-chatwoot` remote and baseline release reference are recorded for future reviewed updates.
- [x] Application smoke tests verify boot, sign-in, Business Account isolation, and V1 navigation visibility.

## Evidence

- `VERSION_CW` records `4.17.0`; `LICENSE` retains the MIT notice; no
  `enterprise/` directory is present.
- `config/installation_config.yml` brands the product as AI Lead Employee and
  disables public account creation by default.
- `README.md`, `docs/adr/0004-community-edition-import-and-upstream-policy.md`,
  and the `upstream-chatwoot` remote record the owned baseline and update path.
- `Procfile.dev`, `config/cable.yml`, `config/initializers/sidekiq.rb`, and
  `config/environments/development.rb` wire the owned local Rails, Vue, Redis,
  and Sidekiq worker stack together.
- `spec/requests/owned_baseline_smoke_spec.rb` covers health boot, sign-in,
  password recovery, admin team invitation, invite-only defaults, and
  cross-Business Account request, query, and background-job rejection.
- `app/javascript/dashboard/components-next/sidebar/specs/aiLeadEmployeeNavigation.spec.js`
  covers the allowed V1 top-level navigation source rendered by the sidebar and
  hides unrelated Community Edition surfaces.

## Blocked by

None - can start immediately.
