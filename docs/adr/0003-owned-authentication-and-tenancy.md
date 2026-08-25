---
status: accepted
---

# Own authentication and tenancy at the application boundary

AI Lead Employee owns its user accounts, authentication sessions, invitations,
password recovery, and Business Account memberships. Reusing the Community
Edition's Devise-based authentication libraries is an implementation choice; it
does not create a Chatwoot account or service dependency.

V1 is invite-only. An initial Human Operator is provisioned during deployment,
then an `admin` can invite `team_member` users. Email and password sign-in,
email verification, password recovery, session revocation, and rate limiting
are available from the first production release. Multi-factor authentication is
enabled for admins before an external-client launch and may be enabled for all
members by a Business Account policy later.

Every request resolves the active Business Account from a signed session and a
server-side `business_account_memberships` lookup. The browser may request a
different Business Account only by selecting one for which the signed-in user
has a membership. It must never establish tenant scope by sending an arbitrary
Business Account identifier. All tenant-owned queries and background jobs carry
the resolved Business Account scope.

V1 roles are deliberately narrow:

- `admin`: manages the Business Account, members, integrations, knowledge,
  settings, and all conversations.
- `team_member`: works assigned and visible conversations, leads, reviews, and
  bookings, but cannot manage members, integrations, or account-wide settings.

The data model permits one person to join several Business Accounts. The V1
interface defaults an internal user to their sole Business Account and only
shows an account switcher when more than one membership exists.

## Consequences

- The existing Community Edition `User`, account membership, session, and
  invitation foundations can be retained and rebranded rather than replaced
  before the first WhatsApp round trip.
- Authorization is enforced in the Rails policy/query layer and verified in
  background jobs, not merely hidden in the inbox interface.
- Enterprise SAML, granular custom roles, and account impersonation are
  deferred. They are not required to safely operate the internal V1.
