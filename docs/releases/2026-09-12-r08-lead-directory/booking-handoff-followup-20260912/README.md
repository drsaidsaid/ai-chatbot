# R08 related-booking handoff follow-up

This focused follow-up fixes the route-handoff failure recorded in
`browser-keyboard-route-acceptance-20260912`. The frozen source evidence remains
historical: its observed failure used a booking-only query, which loaded the
workspace's default date range and excluded a future booking.

The fix changes a related booking URL from `booking_id` alone to `booking_id`
plus `from`, set to the booking's local start date. The Bookings workspace keeps
its normal date-range filter, and the destination range contains the linked
booking. No visibility scope is widened and no permission check is bypassed.

Fresh isolated in-app-browser observations:

- From a selected lead at
  `q=Alexandra&quality=highly_qualified&sort=name&direction=asc&page=1`, the
  related booking link now opened
  `/app/accounts/3/bookings?booking_id=1&from=2026-09-14`.
- The Booking workspace displayed `Sep 14 - Sep 20, 2026`, `Showing 1 of 1
  bookings`, the featured booking card, and its Selected Booking detail with
  the featured lead, Confirmed status, Product Demo, and assigned operator.
- The Leads detail `Back to leads` action cleared only `lead_id`; it retained
  the nondefault search, quality, sort, direction, and page context.

Validation passed:

- `bundle exec rspec spec/services/ai_lead_employee/leads_directory_service_spec.rb`
  with the isolated test database and local test-only encryption values: 7
  examples, 0 failures.
- `pnpm test app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js`:
  16 tests passed.
- Targeted RuboCop and ESLint completed with no offenses or errors.

The workspace-wide `pnpm eslint` command completed with zero errors and 507
pre-existing warnings outside this focused change; the direct targeted ESLint
command completed cleanly.
