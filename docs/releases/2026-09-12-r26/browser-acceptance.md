# Browser acceptance observations

The acceptance session used a fresh Codex in-app browser, an isolated local
production Rails runtime, and synthetic account, user, inbox, and template
records. The browser never contacted Meta.

## Desktop

The WhatsApp templates page loaded inside the owned AI Lead Employee settings
shell. The form visibly exposed WhatsApp inbox, name, language, category,
template body, optional media header, optional button, variable sample values,
recipient preview, and the saved-template list.

Without saving, the session selected the synthetic WhatsApp inbox and filled:

- name: `browser_preview_only`
- body: `Hello {{1}}`
- media: Image with `https://example.test/image.jpg`
- button: Quick reply with `View order`
- variable sample 1: `Asha`

The recipient preview visibly changed to `Hello Asha`. A final read-only reload
against the post-commit production bundle showed:

- `approved_order_update · en_US`
- `Revision 1 · Meta status: approved · Sendable`
- `Meta charge: 0.025 USD · TZ · 2026-09-12 · Synthetic browser fixture`

## Phone viewport

The documented browser viewport capability was set to 390 by 844 pixels. A
runtime measurement reported:

```text
innerWidth=390
innerHeight=844
clientWidth=390
scrollWidth=390
```

The screenshot showed the mobile header, bottom navigation, and a single-column
stacked template form. The accessibility tree retained the complete form,
preview, approved/sendable record, charge evidence, and status-sync action.
There was no horizontal overflow. The viewport override was reset afterward.

## Deliberately unexercised browser actions

The session did not click **Save draft**, **Submit to Meta**, or **Sync Meta
status**. Save and sync dispatch are covered by the Vue component tests. Draft
creation, administrator and tenant boundaries, current-revision submission, and
duplicate request behavior are covered by request specs. Submission,
idempotency, timeout recovery, reconciliation, and provider statuses are covered
with fake-provider service specs.

The isolated Rails server was stopped. Ports 55547 and 6447 were confirmed
released at handoff.
