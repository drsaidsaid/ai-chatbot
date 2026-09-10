# Invitation mail capture in the test environment

Correction commit: `58adb4b904ab8b480c7723288bce7ebec900f8de`.
Final SMTP-unset verification passed all 14 examples: three real invitation
flows and 11 confirmation-mailer checks, in 7.06 seconds after an 8.78-second
Rails load. Both changed Ruby files and normal commit hooks passed strict lint.
The heavy-check slot is released. Independent coordinator Standards and Spec
reviews both have zero findings; both source hashes match the reviewed commit.

The coordinator's isolated invitation run on combined candidate `c40a190`
failed two of three examples: invitation requests returned 200, but the real
email was absent from ActionMailer's test deliveries. The failing run used the
correct disposable spec database and reproduced the earlier broad-run failures
in isolation. `red.txt` preserves that actual result.

`config/environments/test.rb` explicitly selects the `:test` delivery method.
The mailer initializer protected its SMTP assignment from the test environment,
but its later sendmail fallback lacked that guard. With SMTP absent at startup,
the fallback replaced `:test` with `:sendmail`. The invitation spec's SMTP
override happened after Rails boot, so it enabled mail generation without
correcting the already-selected delivery transport.

The coordinator's private test environment omitted the SMTP key; R06's local
release environment supplied it before boot. Only presence/nonblank booleans
were compared. No private environment values were printed or copied. Nine
relevant runtime, spec, configuration and dependency inputs were byte-identical
between the two checkouts.

The correction adds the same test-environment exclusion to the sendmail fallback
that already protected SMTP. Non-test delivery behavior is unchanged. The
invitation helper now asserts the actual boot-selected `ActionMailer::Base`
delivery method before making any invitation request. Its per-example SMTP
override cannot change that already-selected transport. A wrong startup
transport therefore fails before a mail
attempt. The real invitation email, extracted generated token, acceptance,
session access, expiry and account-specific revocation checks remain intact.
No token is fabricated and no delivery is manually inserted into the catcher.

Final checks must boot with `SMTP_ADDRESS` absent, rather than supplying a hidden
SMTP setting to bypass the initializer defect. Results, source hashes and review
provenance are recorded in `checks.json`. The run followed R09's explicit slot
release, and release afterward was sent to the coordinator, R09 and R11. This
correction required no fixture server, browser run or frontend build.

A read-only before-suite probe records whether SMTP is blank and the sender
override absent, plus the configured/effective transport, before any example
changes SMTP. It does not set a delivery method or alter tokens or deliveries.
Both SMTP and sender overrides are removed before the accepted run, matching
the coordinator's fixture and preserving the confirmation-mailer's existing
default-sender assertion.

Both earlier 14-example passing runs are preserved. Strict lint required moving
the assertion out of the around hook and expressing the same property check with
`have_attributes` to keep the invitation helper within its complexity limit.
The final passing run uses the exact committed source; no lint rule was disabled.
