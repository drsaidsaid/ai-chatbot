# R09 browser acceptance resume — prepared offline, not executed

The frozen final source is ee1f82ed55bd2a8878ceedc6ddef0f89b3030984. Root reported a fresh Mac-lock/automatic-unlock failure plus browser request-header policy error. Browser acceptance remains pending; no server has been launched and no browser evidence is claimed. Root owns the pending owner unlock request and must allocate the in-app browser/server before execution.

## Allocated setup sequence

1. Once root confirms in-app browser access and reserves a loopback port, use this R09 worktree and verify the non-release source manifest still matches the tested source. Record any later fix as a new source with separate affected checks.
2. Create a separate disposable browser database, proposed name `ale_r09_offers_20260912_browser`, on the existing local PostgreSQL instance. Do not reuse or change the test-run database `ale_r09_offers_20260911_spec`. Use the local private environment loader without printing values. Run only this repository's schema/migrations against the new named database, with Rails test mode and the owned CE runtime.
3. Seed synthetic accounts/users/contacts/inboxes; abort seeding if that browser database already contains Accounts or Users. Obtain the synthetic administrator password through a private environment variable and do not put it in release evidence. ConfigLoader must populate installed configuration before login, as in the existing R03 browser fixture.
4. Use a test-only server adapter based on `script/release/r10_browser_server.rb`: enforce the exact browser database and Rails test mode; block outbound network through WebMock with localhost allowed; keep jobs and mail in test adapters; point ViteRuby at the completed production build with auto-build disabled. Bind Puma to the coordinator's allocated loopback port. Use a dedicated Redis channel prefix and explicit local ActionCable origins. Do not start Sidekiq or a Vite development server. This is a synthetic browser environment, not live provider proof.
5. Record server PID, URL, source tree, database name and fixture record IDs in a local non-secret fixture manifest. Root then opens the URL using the in-app browser. Save real screenshots/UI observations only after successful access. Stop the owned server and release browser allocation afterward.

## Fixture inventory

- Business A: one administrator, one assigned agent and a second agent for assignment isolation. Business B: independent administrator/Offer to exercise tenant switching. Use reserved example.test addresses and synthetic phone identifiers.
- Two independent Offers in A: Message support (TZS minimum 500000.00) and Sales training (TZS minimum 900000.00). Required budget and problem questions have distinct prompts. Include a saved budget score rule with delta 15 and an explicit zero built-in budget weight, as in the canonical Offer request spec. Configure/save these through the dashboard during acceptance so the configuration path itself is exercised.
- One Lead with two Conversations explicitly selected to different Offers, plus an unrelated restricted Conversation for the assigned-agent check. No implicit latest-Conversation selection. Add a legacy/unselected record to inspect neutral legacy labeling.
- Replay the existing canonical fixture sequence from `spec/requests/ai_lead_employee/offer_qualification_spec.rb`: create incoming Message and OrchestrationIntent, then invoke OrchestrationIntentJob. The first Offer receives `Bajeti yangu ni TZS 600000.`; the second receives `Hello`. Keep the same documented test-only launch/provider preparation as those request specs and block all real sends. Do not fabricate qualification/evidence/decision rows directly to claim canonical behavior.
- Additional incoming cases: an explicit English budget denial; uncertainty; a later positive correction with a new source Message. Include a human evidence edit with its actor. Do not alter source records in place to imitate correction history.
- Keep a pre-edit configuration/evaluation pair, then change a threshold through the UI to show stale/current revision state. Create a new unused Offer for the currency-round-trip case; used money fields intentionally reject a currency semantic change.

## In-app acceptance sequence

1. Open `/app/accounts/<A>/settings/ai-lead-employee/offers-qualification`. Create the two Offers, edit typed questions/order/required/enabled flags, budget range and score rule, save and reload. Confirm TZS 500000.00 remains 500000.00, with explicit currency. On the unused Offer, change currency and inspect that money-rule labels/values follow it without multiplying the amount.
2. Open two views of one revision, save one and then attempt the older draft. Confirm visible conflict and retained draft. Check invalid ranges and incompatible rule values produce a useful error with draft retained.
3. On `/app/accounts/<A>/leads`, explicitly choose each Offer. Open the Lead and verify selected Offer identity, score/reason, current/evaluated revision, evidence polarity, missing signals and next question. Check export uses the same selected Offer. Switch Offers while a read/edit is pending and verify old results cannot overwrite the new Offer or leave its controls busy.
4. Open `/app/accounts/<A>/conversations/<display_id>`. Confirm Offer selection and qualification summary agree with the Lead view; follow the source-message link and see the correct message. Budget answered for Message support must lead to its problem question; the Sales training Conversation must still ask its own budget question.
5. Inspect denial, uncertainty and later correction in evidence/history. Human edits show the actor/source and update only the selected Offer. No unsupported highly-qualified result may be inferred merely from nonempty keywords.
6. Change a saved configuration and verify affected evaluation becomes stale, with current and evaluated versions distinguishable. Re-evaluate using a new incoming supported message and verify the updated saved rule is used.
7. As an assigned agent, inspect permitted records and fresh denial for the restricted Conversation. Switch Business A/B while a request is pending and verify no former-business data remains. Check desktop and narrow viewport readability, errors and controls without changing existing conversation control actions.

## Evidence boundary

Capture actual route, viewport, screenshot, result and fixture IDs for each observation. Link canonical request-test results separately from browser observations. This runbook, test-suite results and a successful asset build do not themselves establish browser acceptance. Normal-hook commit, integration and deployment remain governed by root's completion decision.
