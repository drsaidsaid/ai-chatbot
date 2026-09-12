# R09 final build and browser acceptance

Date: 2026-09-13
Frozen source commit: `50df1a0433de3911e1a39e5d25ad1ef5a63b8b26`
Frozen source tree: `4d46d1e29e63a30263a507a0558ed9e3fd02cb2f`
Prior evidence-only commit: `f440e141d7315b098393dd278eccc3e6677f0eec`
Application/database: local Rails/Vue runtime on `127.0.0.1`, isolated `ale_r09_offers_20260911_spec`
Browser: Codex in-app browser

The application, database and specification paths are unchanged between the frozen source and prior evidence commit. No provider, customer, deployment or live-production action was used.

## Production build

The first exact Vite production-build attempt used Node's default heap. It transformed all 5,083 modules, then exhausted the 2 GB heap while generating assets. Its complete output is retained in [root-final-production-build-first-attempt.log](root-final-production-build-first-attempt.log).

The retry changed only the build environment by setting `NODE_OPTIONS=--max-old-space-size=8192`. Vite 6.4.2 transformed 5,083 modules and completed in 1 minute 5 seconds. The only reported warnings were the existing stale `caniuse-lite` data and large output chunks. See [root-final-production-build.log](root-final-production-build.log).

## Desktop acceptance

At the normal 1280 × 720 in-app viewport, a local administrator created **R09 optional dimension acceptance** and saved revision 1 with:

- qualification **Enabled** and next step **Offer a sales call**;
- the stable **Sales call agreement** field with **Yes / no** type;
- prompt **Would you like our sales team to call you?**, enabled and not required, assigned to **Action eligibility**;
- a separate enabled, required **Problem to solve** question assigned to **Business fit**;
- no readiness question and no qualification rules.

The page displayed **Offer saved.** Reloading the route and selecting the Offer restored its name, revision 1, enabled qualification, sales-call next step, both question meanings/types/prompts, optional agreement state, required fit state and empty rule list.

## Phone-width acceptance

The in-app browser viewport override was set to 390 × 844. The mobile header, settings selector and mobile navigation were visible. The persisted Offer remained fully editable. The Sales Call Agreement prompt was changed to **Would you like our sales team to call you now?**, saved as revision 2, reloaded and selected again. The revised prompt and all optional-dimension settings persisted.

Measured before and after the phone-width reload: `innerWidth = 390`, `clientWidth = 390`, `scrollWidth = 390`, `innerHeight = 844`. There was no horizontal overflow. The viewport override was reset after acceptance; the browser returned to 1280 × 720.
