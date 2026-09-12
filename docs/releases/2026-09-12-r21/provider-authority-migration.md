# R21 provider authority migration and rollback

## Scope

R21 changes who may administer the existing account-attributed AI Provider
Connection. It does not move, decrypt, rotate, duplicate, or pool credentials.
Each existing `ai_provider_connections.account_id` remains the Business Account
attribution used by runtime admission, health evidence, configuration revisions,
usage and cost records.

The authority cutover is deliberately route- and policy-based:

- Business Account admins retain read-only access to a managed-service payload
  containing readiness and that account's usage allowance.
- Business Account admins and Team Members cannot read provider identity, model,
  credential presence, provider failure details, provider costs or configuration
  revisions.
- Client update, disable and health-check routes are removed.
- The existing platform API authenticates a Platform App access token and
  requires an explicit `PlatformAppPermissible` grant for the target Account
  before configuration, health check or disable actions.

## Release transition

1. Before release, inventory connection and usage counts grouped by Account ID;
   record counts only and never output encrypted columns or decrypted values.
2. Provision the operations Platform App through the existing protected
   platform administration process. Grant only the Accounts the operator is
   authorised to manage.
3. Deploy the route, controller, serializer and UI cutover together. No data
   backfill is required because row ownership and encrypted storage do not
   change.
4. Verify, with a fake provider only, that one explicitly permitted Account can
   be read and changed through the platform boundary and an unpermitted Account
   receives the same authorization failure whether or not a connection exists.
5. Verify each Business Account admin receives only managed readiness and its
   own usage. Do not rotate a live credential or run a paid health check during
   this transition.

In-flight changes preserve R10's fencing: the connection row is locked only for
the local configuration commit; its revision increments and readiness resets;
then pending automation is invalidated after the provider lock is released.
Provider HTTP remains outside database locks. A dispatch authorised before the
commit may finish, while work observing the committed revision change fails
closed.

## Rollback

Rollback requires the previous application release, not a database reversal:

1. Stop new platform configuration actions.
2. Deploy the prior application release, restoring its account-admin routes and
   UI as one unit.
3. Revoke the temporary operations Platform App grants or token if they are no
   longer required.
4. Verify connection counts, encrypted ciphertext presence, configuration
   revisions, readiness observations and usage/cost counts against the
   pre-release inventory.

No credential restoration is required because R21 never rewrites credentials
during migration. A configuration change intentionally made by a Platform
Operator before rollback remains the current configuration and revision; never
silently restore an older key or model. Disablement still clears the credential
by design and therefore requires an explicit authorised rotation after rollback.

## Partial failure

- Authentication or Account permission failure occurs before connection lookup
  is returned to the caller and reveals no connection state.
- Validation or encryption failure leaves the prior connection unchanged.
- A committed configuration change remains authoritative even if later pending
  automation cleanup fails; revision checks still fence stale work.
- Usage and provider cost records remain account-scoped. Missing provider cost
  remains unknown and is never rewritten as zero.
