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

- [ ] The pinned Community Edition `v4.17.0` source runs from the owned repository root with its MIT notice retained and no Enterprise code imported.
- [ ] The owned Rails, Vue, PostgreSQL, Redis, and background-worker stack boots locally using application-owned configuration only.
- [ ] The operator experience keeps the Community Edition dashboard shell, inbox layout, component conventions, Tailwind styling approach, and interaction model.
- [ ] The product is branded AI Lead Employee and does not require a Chatwoot account, cloud API token, or webhook secret.
- [ ] An initial admin can be provisioned, sign in through owned invite-only access, recover a password, and invite a team member.
- [ ] Server-side membership resolution prevents a user, request, job, or query from accessing another Business Account.
- [ ] V1 navigation exposes only Inbox, Hot Leads, Leads, Reviews, Knowledge, Bookings, and Settings as native-feeling Community Edition dashboard surfaces; unrelated Community Edition surfaces are hidden.
- [ ] The `upstream-chatwoot` remote and baseline release reference are recorded for future reviewed updates.
- [ ] Application smoke tests verify boot, sign-in, Business Account isolation, and V1 navigation visibility.

## Blocked by

None - can start immediately.
