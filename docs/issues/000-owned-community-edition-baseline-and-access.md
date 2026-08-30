# Owned Community Edition Baseline, Access, and Route Audit

**Status:** Replacement blocker ticket

## What to build

Confirm and repair the owned Community Edition foundation before changing lead
behavior. The application must boot as AI Lead Employee without a Chatwoot Cloud
account, Chatwoot API token, Chatwoot webhook secret, separate Chatwoot
database, or Enterprise code. Audit the current WhatsApp and AI additions and
mark duplicate custom Meta routing as donor code, not production.

## Acceptance criteria

- [x] The pinned Community Edition source, MIT notice, upstream reference, and
      Enterprise exclusion are verified.
- [x] User, Account, AccountUser, Devise, invitation, role, and Business Account
      scoping behavior are retained and rebranded for owned access.
- [x] Server-side policy and query checks prove an admin and team member cannot
      cross Business Account boundaries.
- [x] V1 navigation exposes only Inbox, Hot Leads, Leads, Reviews, Knowledge,
      Bookings, and Settings; unrelated Community Edition surfaces remain hidden.
- [x] The code audit identifies all callers of the duplicate
      `/webhooks/meta/whatsapp` path and inline AI reply behavior.
- [x] The implementation plan for ticket 001 says exactly how the duplicate
      custom Meta path will be retired or quarantined.
- [x] Smoke checks cover boot, sign-in, invite-only access, tenant isolation,
      and V1 navigation visibility.

## Delivery notes

- Audit artifact: `docs/audits/000-owned-community-edition-baseline-and-access.md`.
- The duplicate `/webhooks/meta/whatsapp` route is quarantined with `410 Gone` and does not call the custom processor or inline AI service.
- `LeadQualificationPolicy` and the lead qualification API now prove Business Account scope for admins and team members.

## Blocked by

None - can start immediately.
