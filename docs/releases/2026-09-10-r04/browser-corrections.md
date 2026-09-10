# R04 browser-discovered corrections

The first allocated in-app browser walkthrough used accepted source
`e1158876814e18617432065ee3b821048aedf4d6`, the preserved synthetic R04 account,
Rails 3224 and the loopback provider 3225. It exposed two concrete defects.
**The corrected browser walkthrough is still pending allocation after R06.**

## Observed failures

An operator created Message 8 through the actual Inbox. It displayed Pending,
then the real SendReplyJob made one local HTTP request and persisted acceptance
with `wamid.R04.BROWSER.5`. The live Inbox remained Pending. Reload displayed
“Accepted by WhatsApp; awaiting delivery.” The server did transmit the update:
the payload itself contained pending attributes from an older Message instance.

The preserved Unknown Message 5 was followed by another same-minute reply from
the same sender. MessageList grouped the replies and suppressed Message 5's
metadata, hiding its delivery label. The unknown review remained in storage.

The screenshots and DOM snapshots in `browser/` record these failures. They are
failure/reload comparisons, not acceptance of the corrected path. The original
seeded-state screenshot is 1280×720; the new reply/reload checks used a verified
1440×1000 viewport. Screenshot files retain the browser's original JPEG bytes.

## Corrections and regression evidence

Message-update broadcasts now load the current Message by account and ID before
building their payload. They retain the original `previous_changes` and
`performer`, while taking all content, provider identity and delivery metadata
from the current persisted row. Missing/deleted rows do not broadcast. This
also prevents older queued updates from reversing newer receipt history.

Both reviewers caught an optional-field issue in the first implementation:
merging fresh fields into the old payload could retain removed attachments.
The final implementation builds from fresh data and retains only the two event
metadata fields. A persisted attachment/native soft-delete regression reproduced
the problem before correction. The reviewers' final targeted rereviews are clear.

MessageList keeps individual metadata for each owned delivery, even within a
single sender's minute. Normal grouping remains for messages without owned
delivery state. The regression mounts the actual MessageList, Message, text
bubble and MessageMeta, with the real HTML sanitizer and transform.

- `browser-live-broadcast-red.txt`: actual Message POST → SendReplyJob →
  ActionCable broadcast reproduced stale accepted and failed outcomes; unknown
  was already correct (3 examples, 2 failures).
- `browser-grouping-red.txt`: six owned delivery states lost metadata in the
  actual grouped MessageList; normal grouping passed (7 tests, 6 failures).
- `browser-stale-attachment-red.txt`: an older queued update retained an
  attachment removed by native soft-delete operations (4 examples, 1 failure).
- `browser-grouping-green.txt`: all 25 Inbox tests pass, including six visible
  per-message states and preserved normal grouping.
- `browser-fixes-ruby-final.txt`: **301 examples, 0 failures**, including actual accepted/failed/unknown broadcasts,
  repeat-job safety, one unknown review, actual Inbox retry, takeover cancellation,
  later provider failure and preserved event metadata, plus the previous R04 suite.
- `browser-fixes-production-build.txt`: production build passed, **5,078 modules,
  14m41s**, using the allocated build slot and a 6GB Node heap.
- `browser-fixes-rubocop.json`: 3 files, 0 offenses. `browser-fixes-eslint.txt`:
  changed frontend files pass with 0 errors and 0 warnings.

## Isolated browser runtime

The ignored `tmp/release-r04/browser_runtime.rb` keeps Rails in test mode and
refuses any database other than `ale_release_r04_browser` or any provider base
other than `http://127.0.0.1:3225`. WebMock blocks external HTTP. Mail uses local
files. Delivery jobs remain held in the test adapter; only ActionCable broadcast
jobs execute inline, using isolated Redis 6394 and channel prefix `r04_browser`.
The same runtime is loaded by the server and manually executed delivery worker.
ViteRuby serves the existing production `public/vite` assets with auto-build off.
No application mode, authorization rule, provider receipt or launch approval is
forged to complete a browser check.

The exact launcher and worker helper are preserved as `browser/runtime.rb.txt`,
`browser/server.rb.txt` and `browser/action.rb.txt`. Copy them into the ignored
`tmp/release-r04/` directory as `browser_runtime.rb`, `browser_server.rb` and
`browser_action.rb`, then load the existing private environment without printing
it. The server command is:

```sh
set -a
. tmp/release-r04.env
set +a
POSTGRES_DATABASE=ale_release_r04_browser \
  WHATSAPP_CLOUD_BASE_URL=http://127.0.0.1:3225 \
  bundle exec rails runner tmp/release-r04/browser_server.rb
```

After creating a new reply through the Inbox, set `R04_MESSAGE` to its exact
synthetic content, `R04_ACTION=dispatch` and `R04_EVIDENCE` to a local JSON
filename, then run `browser_action.rb` with the same two environment overrides.
`repeat` runs the same sender job three more times to verify no redispatch;
`provider_failed` projects a synthetic later failure through the real status
projector. Each run records provider counts and persisted Message/delivery/review
evidence, and verifies no launch gate has been approved.

The browser slot was released to the coordinator/R06 while these corrections
were implemented and checked. No R06 tab, service, combined verification
checkout or shared integration was changed. Final browser acceptance still needs
fresh desktop and phone replies, live/reloaded outcomes, retry controls and
duplicate-send/review checks before R04 can be integrated.
