# Isolated browser acceptance

The corrected production application was exercised in the Codex in-app browser
against a deterministic fake Meta server on loopback. The account, user, inbox,
template, media handle, and provider IDs were synthetic. No live Meta endpoint
or customer was contacted.

## Desktop functional path

The owned Settings navigation visibly exposed **WhatsApp templates**. The form
saved `browser_correction_20260913` revision 1 with:

- language `en_US` and category `UTILITY`;
- BODY `Hello {{1}}, your order {{2}} is ready.` with recipient examples
  `Asha` and `A-123`;
- IMAGE header sample handle `fake-header-handle-r26`;
- Website button `View order` with URL
  `https://example.test/orders/{{1}}`;
- no price fields, so the UI truthfully displayed the Meta charge as unknown.

The recipient preview visibly rendered the image-header sample, substituted
body, and website button. Save produced revision 1 as `not_submitted` and not
sendable. Submit produced `submission_pending`, then `submitted`, without a
customer message. The fake provider recorded the Meta-compatible create body.

Reconciliation then visibly exercised:

1. `REJECTED` with `FAKE_POLICY_REVIEW`: revision 1 was rejected and not
   sendable.
2. an empty provider result: revision 1 became `unknown`, remained not
   sendable, and the prior rejection text disappeared.

Editing loaded the existing values while inbox, name, and language were visibly
disabled. Changing only the category to `MARKETING` and saving created revision
2 while revision 1 remained in immutable history. Submit used
`POST /v22.0/fake-browser_correction_20260913` with only category and components;
the fake provider recorded one edit operation rather than a second application
create operation.

Three controlled approved responses then proved the reconciliation boundaries:

1. approval for the prior `UTILITY` representation left revision 2 `unknown`
   and not sendable;
2. approval for the current `MARKETING` representation with provider ID
   `fake-wrong-provider` also left it `unknown` and not sendable;
3. approval with the current category, components, and known provider ID made
   revision 2 `approved` and sendable.

The visible final history was revision 2 `approved · current` and revision 1
`unknown`. A production database read confirmed revision 1 `sendable: false`,
revision 2 `sendable: true`, the shared retained provider ID, and no rejection
reason on either revision.

## 390 × 844 responsive path

At an explicit 390 × 844 viewport the settings destination collapsed to a
mobile selector and the owned mobile navigation remained visible. The page
reported `innerWidth`, document `clientWidth`, document `scrollWidth`, and body
`scrollWidth` all as 390 pixels, demonstrating no horizontal overflow.

The edit form, recipient preview, Save-new-revision and Cancel controls, saved
template card, Sync control, and expanded revision history were accessible. The
current approved/sendable state and historical unknown state remained readable
in the narrow layout. The temporary viewport override was reset after capture.

## Safety invariant

`Message.count` was 0 after the complete Save, Submit, Sync, Refresh, edit, and
history path. This acceptance run created no customer message and made no live
provider request.
