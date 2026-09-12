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

## Green frontend check

Command:

```text
/opt/homebrew/bin/pnpm exec vitest run app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/OwnedSettingsLayout.spec.js app/javascript/dashboard/routes/dashboard/settings/aiLeadEmployee/specs/WhatsappTemplatesPage.spec.js --reporter=dot
```

Observed after commit-hook formatting:

```text
Test Files  2 passed (2)
Tests       5 passed (5)
```

Coverage includes settings navigation, recipient substitution, media and button
preview, type-correct draft payloads, edit-as-new-revision, immutable history,
unknown and owner-verified price display, sync dispatch, and refresh. Output
contained the existing Browserslist data warning.

## Production bundle replay

Command at corrected source `b37d5de28f6a97a78aa213baad1b40f6ba158de1`:

```text
NODE_OPTIONS=--max-old-space-size=4096 RAILS_ENV=production NODE_ENV=production /opt/homebrew/bin/pnpm exec vite build --config vite.config.ts
```

Observed:

```text
vite v6.4.2
5080 modules transformed
built in 1m 9s
exit 0
```

Manifest SHA-256 values:

```text
f7fd3e3277b561ca4409beeea5c264637b12fef8b219c8d2957c681757d89389  public/vite/.vite/manifest.json
44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  public/vite/.vite/manifest-assets.json
```

The build reported only the existing outdated Browserslist database and large
chunk warnings.

## Lint and patch checks

- Targeted RuboCop over all changed Ruby implementation and spec paths: six
  files inspected, no offenses detected.
- Targeted ESLint over the four changed Vue/JavaScript paths: zero errors. It
  reported existing warning-class raw-text, dynamic-i18n-key, and HTML-style
  notices.
- `git diff --check`: exit 0 before the source correction commit.

No live Meta request, customer message, push, integration, deployment, or issue
closure occurred.
