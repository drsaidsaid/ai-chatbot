# R08 fresh in-app-browser acceptance

This checkpoint validates the frozen R08 product source at
`2d898a3d6766f9b8846f91ba90ba1056675ac56a`. It follows the prior immutable
combined evidence commit `4e58e07faa4e451032437e56f2c01f3c0a1ebae6` and
contains no production-code change.

The run used a new disposable PostgreSQL database on `127.0.0.1:55533`, Redis
on `127.0.0.1:6433/1`, Rails on `127.0.0.1:3000`, and Vite on
`127.0.0.1:3036`. It created one isolated account, an administrator, one
restricted operator, 112 contacts across all quality states, a featured long
name contact, a conversation, and a booking. No shared default database,
background worker, external provider, Chrome, or production resource was used.

The Codex in-app browser rendered the desktop directory and selected detail;
the desktop detail included the contact channels, qualification, long-name
truncation, conversation state, AI control state, assignee, booking, and action
links. It also rendered the mobile directory at `390x844`, including cards,
quality chips, filters, pagination, and the bottom navigation. Fresh in-app
browser screenshots were captured inline in the acceptance transcript. The
browser interface does not provide a filesystem path for screenshots, so this
package records the exact visible assertions rather than claiming local PNG
artifacts.

The initial mobile selection momentarily displayed incomplete related data while
its request was still loading. A reload and completed loading state showed the
same contact channels, evidence, conversation, and booking as desktop. This is
recorded as an asynchronous loading observation, not a persisted data-loss
finding.

The browser emitted no console errors for either session. See
`acceptance.json` for every observation and explicit limitation.
