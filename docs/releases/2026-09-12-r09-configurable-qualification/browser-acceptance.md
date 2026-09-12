# Browser acceptance record

Date: 2026-09-12  
Source commit: `1e460bb20de3193c4376faf7b415fe081b63eee3`  
Source tree: `36c3d18ba3b5e3d8324d67351e4cfe4a2217a1fd`  
Browser: Codex in-app browser  
Observed viewport: 1280 × 720  
Application: local Rails/Vue runtime on `127.0.0.1`  
Database: isolated `ale_r09_offers_20260911_spec`

## Result

Desktop acceptance passed for the amended R09 settings flow.

1. Signed into a local administrator test account and opened **Settings → Offers & qualification**.
2. Confirmed the qualification-mode selector exposes **Not configured**, **Disabled**, and **Enabled**.
3. Confirmed the next-step selector exposes **Answer only**, **Continue the enquiry**, **Share a purchase link**, **Offer a sales call**, and **Offer an appointment**.
4. Added a Purchase budget question and confirmed **What this answer decides** exposes **Business fit**, **Readiness**, and **Action eligibility**.
5. Added a rule, selected **Required for a decision**, and confirmed **Decision area** exposes **Business fit**, **Readiness**, and **Action eligibility**.
6. Saved an enabled Offer named **Browser acceptance Offer** with:
   - next step **Offer a sales call**;
   - question **What monthly budget have you approved?**;
   - question purpose **Action eligibility**;
   - rule result **Required for a decision**;
   - decision area **Action eligibility**;
   - currency **TZS**.
7. Observed the **Offer saved.** confirmation and revision 1.
8. Reloaded the page and confirmed the Offer name, enabled mode, sales-call next step, question text, question purpose, required-decision rule, decision area, currency, thresholds, and revision persisted.
9. Confirmed the page states that questions are asked in order, one at a time, and exposes the existing Offer selector, currency selector, question ordering controls, budget ranges, rules, and score thresholds.

## Phone-width follow-up

Date: 2026-09-12  
Source commit: `1e460bb20de3193c4376faf7b415fe081b63eee3`  
Source tree: `36c3d18ba3b5e3d8324d67351e4cfe4a2217a1fd`  
Browser: Codex in-app browser viewport capability  
Viewport: 390 × 844

Phone-width acceptance passed. The browser viewport override was reset after the run.

1. Opened the existing **Browser acceptance Offer** at 390 × 844. The native mobile navigation and settings-section selector were visible, and the Offer configuration remained fully editable.
2. Confirmed the qualification mode choices, five next-step choices, three question-purpose choices, and three requirement decision-area choices were all exposed at phone width.
3. Edited the question text, changed **What this answer decides** from **Action eligibility** to **Readiness**, changed the required-decision **Decision area** to **Readiness**, and saved successfully.
4. Observed **Offer saved.** at revision 2, reloaded the page, and confirmed the revised question text, purpose, decision area, enabled qualification mode, and sales-call next step persisted.
5. Confirmed no horizontal overflow with `innerWidth: 390`, `clientWidth: 390`, and `scrollWidth: 390`.

The in-app browser screenshots attached to this acceptance run show the responsive header, settings controls, mobile navigation, and lower form controls at the exact 390 × 844 viewport.
