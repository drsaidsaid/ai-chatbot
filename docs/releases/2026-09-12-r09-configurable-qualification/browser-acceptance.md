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

## Limitation

The in-app browser remained at 1280 × 720 and did not expose a usable viewport resize control in this run. Phone-width acceptance could not be executed in the required browser and remains unresolved.
