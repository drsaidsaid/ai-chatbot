# Combined R04 and R06 verification

Status: combined automated checks and independent code reviews passed. The normal-hook verification merge is being recorded. In-app browser acceptance is pending the existing owner Mac-unlock request. Neither ticket is complete or promoted to the accepted integration branch by this work.

The coordinator owns this isolated verification checkout and branch `codex/v1-r04-r06-verification-20260910`. The shared accepted integration remains `f2b184e1c332f0bf68c31dec460f7e5599657a72`.

## Reviewed parents

- R06: `7161f8fef7902ed239f6d52c83f4661b1e533a96`, including accepted R03.
- R04: `e1158876814e18617432065ee3b821048aedf4d6`, including the final normalized receipt-evidence correction.

## Conflict resolutions

Three files conflicted. Both parent intents are preserved without a new product behavior:

- MessagesController keeps R06's authorization-error propagation and R04's non-WhatsApp-only controller control transition. WhatsApp human control still changes once under the Message creation lock.
- Conversation keeps assignment-access invalidation after commit and pending-automation cancellation when its status becomes ineligible.
- The Cloud provider audio fixture uses the canonical recipient identity from R04 and still requires R06's signed `/whatsapp/media/` capability. Existing persisted attachment fixtures are retained.

The automatic MessageBuilder merge retains both R06 upload authorization and R04 reserved receipt-evidence filtering. Provider media remains separate from browser media authorization.

## Validation procedure

The Ruby selection combines the recorded R06/R03 and final R04 selections, removes duplicates and expands provider directories. The frontend selection combines seven R06/R03 files with R04's actual delivery components. Both lists are recorded beside this document.

Dependencies use unchanged locks. Backend dependencies are satisfied by the recorded R04 isolated bundle; frontend dependencies were installed offline from the existing package cache with normal Husky initialization. The coordinator has exclusive serial use of `ale_release_r04_spec`, PostgreSQL55484 and Redis6394. The separate R04/R06 browser databases and fixtures are preserved. Private environment values must never be copied into evidence.

This verification does not send real provider messages, enable live operation or complete Google Calendar behavior. Browser ownership remains R06 followed by R04. The verification merge remains isolated until their required browser acceptance passes.

## Initial results and fixture reconciliation

The first combined Ruby run completed 721 examples with 27 failures. The eight frontend files passed 57 tests. Both independent runtime merge reviews passed on tree `2cdc528e80655d0741706cbd3416b9f9995597ad`, and strict Ruby lint of the four resolved/automatically merged files passed.

The failed cases exposed test-environment and fixture assumptions:

- R04's private environment did not set SMTP_ADDRESS at Rails boot. The inherited mail initializer therefore chose sendmail. Setting a synthetic SMTP_ADDRESS before boot retains Rails' test delivery adapter; both invitation checks then passed without a production change.
- Native Message and Review tests assumed InboxMember membership grants access. Their permitted scenarios now explicitly assign the Conversation to the tested member. Review assignment uses an Admin, while rejection remains the assigned operator's action.
- The direct-upload builder fixture now carries the same server-owned user/account/conversation metadata as an authorized upload and gives the operator the corresponding assignment.
- Greeting fixtures used fixed historical timestamps or invoked the legacy raw service without a durable provider timestamp. The webhook fixture now represents a current incoming message. The service replay fixture goes through a persisted WebhookReceipt and ReceiptProcessor, retaining the real service, greeting delivery and duplicate assertions.

All 93 affected checks then passed. No production runtime was modified for these failures. The only follow-up source changes are five spec files. Their staged tree is `31c82f76c92b313b21a103e07dfd4b2e06bc2750`; a grouping-only correction resolved one ScatteredLet lint finding. Independent Standards and Spec rereviews both returned zero findings on that tree. The Spec review confirmed that permission, upload ownership, provider time and durable-receipt fixtures preserve the intended assertions and existing rejection coverage.

For the combined Ruby selection, load the private R04 environment without logging its values and explicitly set `RAILS_ENV=test`, `POSTGRES_DATABASE=ale_release_r04_spec` and `SMTP_ADDRESS=smtp.example.test`. The last value selects the local test adapter at boot; these checks never send SMTP mail.

## Final automated results

- Ruby regression: 721 examples, zero failures; 8 minutes 54 seconds, plus 53.06 seconds loading. The production build ran concurrently; no other Ruby suite used this database.
- Frontend: 57 tests in eight files, zero failures; 18.06 seconds. Production code did not change after this run.
- Strict Ruby lint: four merged/resolved files and five fixture files, zero offenses in their final runs.
- Production build: successful exit, 5 minutes 51 seconds. Existing large-bundle, source-map, Browserslist and other upstream warnings remain visible in the captured logs; this is not a bundle-size remediation claim.
- Database migrations, schema and dependency lock files are identical to accepted R04 parent `e1158876`. R04 already recorded matching fresh and upgrade schemas. The combined regression used that schema; it did not rerun the fresh/upgrade procedure.
- Both Standards and Spec reviews: zero findings for the runtime resolution and the fixture follow-up.
- Browser acceptance: pending, not represented by any automated result here.

`source-sha256.json` records tracked runtime, spec, release script, dependency, and configuration source before normal commit hooks. `SHA256SUMS` covers the verification evidence except itself and the commit log, which cannot be finalized until the commit finishes. Source hashes are checked again after the hooks. Captured logs have trailing whitespace normalized without changing their substantive content.
