# Ticket 012 Design QA

Result: Passed
Final result: passed

## Reference

- Approved Leads reference:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-92db24dc-b7da-480f-8702-447ebc3433bc.png`

## Screenshots

- Desktop 1487 x 1058:
  `docs/issues/012/screenshots/desktop-leads-1487x1058.png`
- Mobile list 390 x 844:
  `docs/issues/012/screenshots/mobile-leads-390x844.png`
- Mobile detail 390 x 844:
  `docs/issues/012/screenshots/mobile-lead-detail-390x844.png`
- Mobile/tablet list 852 x 1846:
  `docs/issues/012/screenshots/mobile-leads-852x1846.png`
- Mobile/tablet detail 852 x 1846:
  `docs/issues/012/screenshots/mobile-lead-detail-852x1846.png`

## Browser QA

- Desktop report: `docs/issues/012/screenshots/desktop-browser-qa.json`
  - 48 steps, 0 recorded errors.
  - Covered quality tabs, search, empty state, error state, filters, sort,
    pagination, row selection, import, export, edit modal, related conversation
    link, and related booking link.
- Mobile 390 px report: `docs/issues/012/screenshots/mobile-browser-qa.json`
  - 32 steps, 0 recorded errors.
  - Covered quality tabs, search, empty state, filters, mobile sort controls,
    pagination, dedicated mobile detail, back-to-list, conversation link, and
    booking link.
- Mobile/tablet 852 x 1846 report:
  `docs/issues/012/screenshots/mobile-852-browser-qa.json`
  - 2 steps, 0 recorded errors.
  - Covered list wrapping, filters, cards, dedicated detail, and overflow.
- Post-review spot report:
  `docs/issues/012/screenshots/post-review-browser-qa.json`
  - Rechecked desktop 1487 x 1058, mobile 390 x 844, and mobile/tablet
    852 x 1846 after the final access-boundary, i18n, contact-channel,
    conversation-state, and bulk-selection fixes.
  - Confirmed live 112-lead tenant data, page-level bulk selection, detail
    contact channels, conversation status/control state labels, related
    conversation and booking links, no raw enum labels, and no horizontal
    overflow.

## Visual Notes

- Desktop follows the approved dense directory structure: left navigation,
  header search/actions, quality chips, filter row, fixed table columns, selected
  row state, and right detail rail.
- Mobile intentionally becomes list-first below the desktop breakpoint. Lead
  detail opens as a dedicated mobile view with a back control instead of showing
  the desktop side rail.
- The 852 px check caught and fixed the filter row overflow by using a two-column
  mobile/tablet filter grid and reserving the fixed dense filter row for desktop.
- The post-review pass refreshed all same-viewport screenshots after the final
  detail-panel and label fixes.
- No non-scrollable horizontal overflow, clipping, or incoherent overlap remains
  in the recorded viewport checks.

## Accepted Deviations

- Counts, names, source labels, and timestamps come from the seeded tenant data
  instead of the static reference image.
- The implementation keeps the existing Community Edition dashboard shell and
  owned AI Lead Employee navigation rather than introducing a parallel shell.
- Source labels use the real owned data labels available in the tenant dataset.

## Console

Codex in-app browser console showed no new application errors. The remaining
warnings were existing development-environment warnings: the shared modal
`onClose` deprecation and Lit dev-mode notice.
