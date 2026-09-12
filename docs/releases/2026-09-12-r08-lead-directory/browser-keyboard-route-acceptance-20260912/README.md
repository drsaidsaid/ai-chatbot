# R08 keyboard and related-route browser acceptance

This bounded, isolated in-app-browser pass covers the R08 acceptance items that
were deliberately left unclaimed by the preceding browser checkpoint. It was
run against frozen product source `2d898a3d6766f9b8846f91ba90ba1056675ac56a`
(tree `2fd67a4bd519ea768b1155d62a5b586bb8ccb1a3`) and makes no production-code
change.

The pass reused the disposable `ale_r08_browser` PostgreSQL database on port
`55533` and Redis database 1 on port `6433`. The dataset contains the R08
administrator, 112 leads, and featured contact ID 2, with a confirmed booking
ID 1 on 14 September 2026. Rails was bound to `127.0.0.1:3000`; Vite used
`127.0.0.1:3036`.

Observed passes:

- A focused desktop row for the featured lead accepted `Enter`, changed the
  URL to `.../leads?lead_id=2`, and rendered the complete Selected Lead detail.
- After returning to an unselected directory, the same row accepted `Space`,
  changed the URL to the same `lead_id=2`, and rendered the same detail.
- `Open conversation` navigated to
  `.../conversations/1?queue=all`. The rendered conversation showed the
  featured lead, its browser-fixture message, `Human Active`, and the proposed
  booking. Using the primary navigation's Leads action returned to the
  unfiltered directory (`All 112`) with default filters and no stale selected
  detail.

Observed failure:

- The related booking link navigated to
  `.../bookings?booking_id=1`, but the Booking workspace's default range was
  7–13 September 2026 while booking 1 starts on 14 September. It therefore
  rendered `No calls booked yet` and `Showing 0 of 0 bookings`, with no selected
  booking detail. Source confirms the cause: `filtered_bookings` applies the
  date range before `selected_booking_payload` searches the already-filtered
  collection. The query parameter alone cannot surface a linked booking outside
  the default range. The primary-navigation Leads action did return to the
  unfiltered lead directory after this failed handoff.

See `acceptance.json` for the precise observations and `artifact-sha256.txt`
for the relevant frozen source hashes.
