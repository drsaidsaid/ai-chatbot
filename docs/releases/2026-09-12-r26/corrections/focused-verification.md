# Focused correction verification

## Test-first failure observations

Before the corresponding implementation changes, focused examples observed:

- create schema mismatch: BODY examples and button fields did not match the
  Meta request contract;
- reconciliation selected by name alone and attached an older approval or a
  different language;
- reconciliation accepted an old-category approval for a category-only edit
  and could replace a known provider template ID with another ID;
- the service posted new revisions to the create endpoint instead of
  `/{TEMPLATE-ID}`;
- a definitive provider 4xx was reduced to `unknown` with no rejection detail,
  and a repeated unresolved sync did not update its observation timestamp;
- a later unresolved sync retained the rejection text from a prior rejection;
- a historical approved revision remained sendable after a newer draft existed;
- the canonical picker and dispatch path trusted a stale provider cache after
  an owned template acquired a newer non-sendable revision;
- HTTP 401, 403, and 429 submission failures were presented as Meta review
  rejection rather than authentication or throttling failures;
- connection refusal, socket, and TLS transport failures could strand a
  revision in `submitting`, where another perform would no-op;
- the API omitted revision history and accepted unverified price evidence;
- owned settings omitted the WhatsApp templates destination;
- the UI omitted media/button preview, edit/history controls, and verified
  estimate capture.

Each focused example failed for the named missing behavior before its production
change. In particular, the edit-endpoint example observed an unregistered POST
to `/v22.0/waba-r26/message_templates` while expecting
`/v22.0/meta-approved`, and the stale-sendability example observed the older
approved revision returning `true` after revision 2 was created.
The provider-identity slice separately observed a category-only edit becoming
`approved` from the old `UTILITY` response and a known `meta-expected` identity
being overwritten by `meta-other`. The provider-error slice observed an HTTP
400 becoming `unknown` with no reason, and an already-unknown reconciliation
retaining its two-hour-old timestamp. Browser acceptance then exposed the stale
rejection text on an `unknown` revision; a focused service example reproduced
that failure before `unknown!` was corrected to clear the prior reason.

## Green backend check

Command:

```text
POSTGRES_USERNAME=ghalyasaid POSTGRES_DATABASE=ai_chatbot_r26_fix_55539 RAILS_ENV=test bundle exec rspec spec/models/whatsapp_template_revision_spec.rb spec/services/whatsapp/template_submission_service_spec.rb spec/requests/ai_lead_employee/whatsapp_templates_spec.rb --format progress
```

Observed after correction:

```text
25 examples, 0 failures
```

The isolated provider boundary uses WebMock. Coverage includes create and edit
schemas, duplicate-mutation prevention, create and edit timeout reconciliation,
same-name older content, wrong language, rejected/paused/disabled states,
category-only edits, known provider identity, definitive 4xx detail, repeated
unknown-sync timestamps,
immutable history, tenant/admin boundaries, no customer Message creation,
explicit pricing confirmation, and canonical current-revision sendability.
Output contained existing Rails/Rack deprecation warnings only.

Final focused correction checks at source `8fc5ab2dcb759111229e441c3546ab66b5c3ea1d`:

```text
56 service/model/API examples, 0 failures
56 canonical WhatsApp delivery examples, 0 failures
30 picker/template-processing/final-send examples, 0 failures
```

These checks include legacy-only template behavior, owned-current-revision
shadowing in the picker and at dispatch, successful owned revision dispatch,
400/401/403/429 classification, 503 uncertainty, and timeout/socket/connection/
TLS transport uncertainty with one mutation attempt across duplicate performs.

## Green frontend check

Command:

```text
/opt/homebrew/bin/pnpm exec vitest run app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/WhatsappTemplatesPage.spec.js --reporter=dot
```

Observed after commit-hook formatting:

```text
Test Files  2 passed (2)
Tests       6 passed (6)
```

Coverage includes settings navigation, recipient substitution, media and button
preview, type-correct draft payloads, edit-as-new-revision, immutable history,
unknown and owner-verified price display, sync dispatch, and refresh. Output
contained the existing Browserslist data warning.

## Production bundle replay

Command at corrected source `8fc5ab2dcb759111229e441c3546ab66b5c3ea1d`:

```text
NODE_OPTIONS=--max-old-space-size=4096 RAILS_ENV=production NODE_ENV=production /opt/homebrew/bin/pnpm exec vite build --config vite.config.ts
```

Observed:

```text
vite v6.4.2
5080 modules transformed
built in 1m 30s
exit 0
```

Manifest SHA-256 values:

```text
9f36a0279aa98a1c922f647bf7a08862ab99a40f97497ffac39ca4effe29a806  public/vite/.vite/manifest.json
44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  public/vite/.vite/manifest-assets.json
```

The build reported only the existing outdated Browserslist database and large
chunk warnings.

## Lint and patch checks

- Targeted RuboCop over all changed Ruby implementation and spec paths: 12
  files inspected, no offenses detected.
- Targeted ESLint over the two changed Vue/JavaScript paths: zero errors. It
  reported existing warning-class raw-text, dynamic-i18n-key, and HTML-style
  notices.
- `git diff --check`: exit 0 before the source correction commit.

No customer message, push, integration, deployment, or issue closure occurred.
The browser addendum records one immediately rejected live Meta authentication
request caused by an acceptance-harness environment omission; the corrected
rerun used loopback only.

## Superseding post-review verification

The final source checkpoint is
`97d8825c6f833ee18345f294d32dec9b973ad74a` with tree
`2c285c57c767a04caf9834dc8ccf3ce0b20157e6`.

Test-first failures reproduced two remaining unsafe cases: a successful empty
provider catalog retained the prior cache, and a successful nonempty catalog
could omit an approved owned template without blocking it. The correction now
distinguishes request failure (`nil`, preserve trusted cache) from a successful
empty result (`[]`, clear stale cache), and disables only approved current owned
revisions absent from a complete successful provider catalog.

Final focused results:

```text
98 focused model/service/API examples, 0 failures
66 canonical WhatsApp outbound-delivery examples, 0 failures
2 committed-transaction concurrency examples, 0 failures
8 frontend component examples across 3 files, 0 failures
```

The canonical suite covers legacy-only behavior, exact revision/content/provider
identity, ordinary `PAUSED` and `DISABLED` sync, successful empty and partial
catalog omission, picker projection, processor and final dispatch rejection,
and deterministic mutation-before/after-authorization interleavings. The
provider suite also proves failed sync preserves the last trusted cache and
cached `APPROVED` cannot revive a locally paused revision.

An exploratory whole-file run of the pre-existing inbox controller spec
reported 14 failures in unrelated agent authorization and inbox-create
examples. Its exact `message_templates` block passed inside the 98-example
group. No whole-repository green claim is made.

Static and build results:

```text
Targeted RuboCop: no offenses
Frontend ESLint: 0 errors; existing repository warning-class notices remain
git diff --check: exit 0
Production Vite build: 5080 modules transformed, exit 0, built in 1m 14s
```

Production manifest hashes from the final frontend-equivalent build:

```text
dbbcc08c12c8b5d2b9017001bb6241782ce67c587d1deb1c1d3e206fa394039d  public/vite/.vite/manifest.json
44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  public/vite/.vite/manifest-assets.json
```

Before either final browser replay, `loopback_transport_exec.rb` was syntax
checked and exercised: missing provider URL exited 1, `http://192.0.2.1`
exited 1, and `http://127.0.0.1:59999` executed a harmless command with exit 0.
Every Rails setup, seed, server, sync, verification, and cleanup command then
ran through the guard with `WHATSAPP_CLOUD_BASE_URL` fixed to
`http://127.0.0.1:55548`. No Sidekiq process was needed for the read-only replay.
