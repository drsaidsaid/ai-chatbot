# Settings Booking Hours and Team Assignment

Status: Done

## Completed behavior

- Administrators can configure timezone, meeting duration, and business-hour availability.
- Team assignment reuses the owned Community Edition teams surface instead of duplicating membership and assignment behavior.
- Booking configuration remains account-scoped and authorized through the existing Rails controller.

## Verification

- Live browser QA confirmed booking and team settings render without console errors or horizontal overflow.
- Booking configuration controller and Bookings workspace component tests pass.

