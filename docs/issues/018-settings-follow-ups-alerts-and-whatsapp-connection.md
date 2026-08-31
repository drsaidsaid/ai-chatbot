# Settings Follow-Ups, Alerts, and WhatsApp Connection

Status: Done

## Completed behavior

- Administrators can configure incomplete-lead follow-up timing and attempt limits.
- Alerts and WhatsApp connection reuse the existing owned inbox settings surfaces.
- Follow-up delivery commits through a durable outbox, retries provider failures, suppresses cancelled or ineligible sends, and is reconciled every minute.

## Verification

- Live browser QA confirmed all three settings routes render without console errors or horizontal overflow.
- Follow-up scheduling, delivery, cancellation, outbox retry, and cron configuration specs pass.

