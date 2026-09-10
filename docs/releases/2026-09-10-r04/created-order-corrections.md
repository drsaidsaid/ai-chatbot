# R04 delayed creation and reply reconciliation

The coordinator's review of `be6ff3a5003783fd1c909e04e081f84d83d1f6d2`
found that `message.created` still carried the original pending payload. An older
creation job executed after an outcome update could replace accepted/unknown
with Pending through the actual Inbox store. Browser acceptance remains pending
the coordinator's allocation after R06.

## Reproduction and correction

The canonical Message POST queues the real creation job with an echo ID. The
regression holds that exact serialized job, executes SendReplyJob and its
ActionCable updates, then executes the original creation job last. It captures
the original pending creation, outcome update and delayed creation payloads.
The accepted case reproduced Pending after acceptance. Both accepted and unknown
payload captures also reproduced the regression through the actual Vuex
`updateMessage`/`addMessage` actions, `ADD_MESSAGE` mutation and rendered
MessageList, Message, text bubble and MessageMeta.

Both Message event kinds now reload the current Message by account and ID when
the broadcast job runs. Payloads start from fresh persisted data and keep only
the original event's `previous_changes` and `performer` metadata, plus `echo_id`
for creation. Both event kinds are covered for current receipt status, original
metadata, native attachment removal, deleted Messages and account scoping.

Both local reviewers then found a combined ordering gap: an outcome update can
arrive while only the optimistic reply exists. The update adds a persisted-ID
row; creation previously replaced the optimistic row without removing that
second copy. An expanded real-store/render regression reproduced two visible
copies for both accepted and unknown outcomes. Creation reconciliation now keeps
the first matching position and removes other matches to either server or echo
ID. An unrelated reply with identical text remains unchanged. Direct optimistic
creation and creation after a persisted pending reply remain covered.

The API test compares actual captured payload projections with the committed
`whatsappCreatedOrdering.json` fixture after independent pending/outcome/echo
assertions. The Vue tests replay that fixture through the production store and
rendered list. This proves the delayed job execution sequence described above;
it does not assert global ordering across every transport or worker schedule.

## Evidence

- `created-order-api-red.txt`: original serialized creation job after outcome,
  1 example, 1 failure (accepted reverted to pending).
- `created-order-store-red.txt`: captured original payloads through the actual
  store and MessageList, 11 tests, 2 failures (accepted and unknown reverted).
- `created-order-optimistic-red.txt`: combined optimistic → outcome → creation,
  13 tests, 2 failures (duplicate persisted-ID rows).
- `created-order-ruby-final.txt`: 306 examples, 0 failures, including the new
  canonical ordering case, eight broadcast preservation/scoping cases and the
  previous R04 sender/recovery/authority/ingress suite.
- `created-order-vue-final.txt`: 56 tests, 0 failures: 31 Inbox component/list
  cases and 25 existing conversation mutation/helper cases.
- `created-order-rubocop.json`: 3 Ruby files, 0 offenses.
- `created-order-eslint.txt`: changed store and list test, 0 errors and warnings.
- `created-order-source-at-build.json` records the exact runtime source hashes
  for the newly allocated production build. `created-order-production-build.txt`
  passed with 5,078 modules in 4m33s; the dashboard asset is
  `dashboard-CBAPqSQd.js`. Runtime hashes still match after the build.

Both reviewers' targeted rereviews report zero remaining findings. They were
read-only; the implementation task owns the execution evidence. The actual
desktop/phone walkthrough remains pending and is not replaced by these checks.
