# Ticket 015 Design QA

Result: Passed

## Browser Evidence

- `docs/issues/015/screenshots/desktop-test-center-final-1536x1024.png`
- `docs/issues/015/screenshots/desktop-release-check-final-1536x1024.png`
- `docs/issues/015/screenshots/mobile-test-center-852x1846.png`
- `docs/issues/015/screenshots/mobile-test-center-390x844.png`

## Viewports

- Desktop exact DOM: 1536 x 1024, document width 1536, horizontal overflow 0.
- Tablet/mobile exact DOM: 852 x 1846, document width 852, horizontal overflow 0.
- Mobile exact DOM: 390 x 844, document width 390, horizontal overflow 0.

## Checks

- Scenarios, Results, and Release check tabs render and switch correctly.
- Active tab computed style is `rgb(8, 109, 224)` text with a 2 px solid `rgb(39, 129, 246)` underline.
- More filters renders as a visible 40 x 40 shared-icon control.
- Scenario labels/counts, transcript evidence, summary counts/tester/time, and Release check live-state text are complete.
- Run test completes as simulation, Results persists the run, and Open transcript shows the persisted transcript.
- Mark wrong opens the correction proposal with populated title, question, and answer; Cancel closes it.
- Release check metrics, required scenarios, blockers, form fields, save state, and disabled approval state render.
- Mobile More opens and exposes Knowledge, Test Center, and Settings; Test Center is reachable.
- No horizontal overflow or incoherent overlap was observed at the required viewports.

## Accepted Deviations

- The app shows 8 real safety scenarios instead of the static reference's sample scenario set.
- The transcript uses the deterministic 2-message simulation output used by the real evaluation sandbox.
- The correction proposal was opened and cancelled during QA; it was not submitted to avoid unnecessary QA data.
