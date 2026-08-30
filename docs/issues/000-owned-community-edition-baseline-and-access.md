# Owned Community Edition Baseline, Access, and Route Audit

**Status:** Replacement blocker ticket

## What to build

Confirm and repair the owned Community Edition foundation before changing lead
behavior. The application must boot as AI Lead Employee without a Chatwoot Cloud
account, Chatwoot API token, Chatwoot webhook secret, separate Chatwoot
database, or Enterprise code. Audit the current WhatsApp and AI additions and
mark duplicate custom Meta routing as donor code, not production.

## Acceptance criteria

- [ ] The pinned Community Edition source, MIT notice, upstream reference, and
      Enterprise exclusion are verified.
- [ ] User, Account, AccountUser, Devise, invitation, role, and Business Account
      scoping behavior are retained and rebranded for owned access.
- [ ] Server-side policy and query checks prove an admin and team member cannot
      cross Business Account boundaries.
- [ ] V1 navigation exposes only Inbox, Hot Leads, Leads, Reviews, Knowledge,
      Bookings, and Settings; unrelated Community Edition surfaces remain hidden.
- [ ] The code audit identifies all callers of the duplicate
      `/webhooks/meta/whatsapp` path and inline AI reply behavior.
- [ ] The implementation plan for ticket 001 says exactly how the duplicate
      custom Meta path will be retired or quarantined.
- [ ] Smoke checks cover boot, sign-in, invite-only access, tenant isolation,
      and V1 navigation visibility.

## Blocked by

None - can start immediately.
