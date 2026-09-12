# R26 WhatsApp template correction evidence

This additive package records the corrections made after review of the frozen
R26 checkpoint. It does not alter or replace the original evidence package in
the parent directory.

- Corrected source commit: `b37d5de28f6a97a78aa213baad1b40f6ba158de1`
- Corrected source tree: `02702ba79604b992e6096eeef05ff2989982c45f`
- Lifecycle correction commit: `75063ebb5c89bc6449aaae4470e7d72833a654b2`
- Media-handle correction commit: `605ecc62b24481bf5d32b63019f2229d135e0794`
- Initial migration-version correction commit: `09d8012f3a8657e6f86ae7c6d0713a74dd060273`
- Provider-identity correction commit: `e771dbbd5ef7c37811804375e5cba3eb38bed956`
- Reserved migration-version commit: `5ac2a3f74ebf0cb91b1d103dd18c4898c2619787`
- Unknown-state rejection cleanup commit: `b37d5de28f6a97a78aa213baad1b40f6ba158de1`
- Evidence checkpoint parent: `ace4c8a1b38e9f8f1609330c37423ff97abeb83a`
- Frozen source candidate: `824d8fbc1ec3428c6eb2fb5722aeaff5f81bf298`
- Baseline and merge-base: `650bff6e08af67b3b67fb01e824dfcbc2141bded`
- Capture date: 12 September 2026, Africa/Dar_es_Salaam

The correction closes the name-only reconciliation ambiguity, aligns create
and edit payloads with Meta's documented endpoints, exposes the feature in
owned settings, adds editing and immutable history, expands the recipient
preview, and permits a charge estimate only when a Business Account admin
explicitly confirms its external source. Missing pricing remains unknown.

The R26 migration is renumbered to the coordinator-reserved `20260912000400` so
it does not collide with the R23 migrations during integration. The
migration body and resulting schema are otherwise unchanged.

`official-provider-contract.md` records the primary-source contract used.
`focused-verification.md` records the red/green checks and production build.
`browser-acceptance.md` records the isolated desktop and mobile acceptance
path. `fake_meta_server.py` is the deterministic local provider boundary used
for that path.
