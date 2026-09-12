# R23 evidence manifest

- Final verified source commit: `190945e22e96341c83a1c7f2cc269942924abbca`
- Final verified source tree: `ad1d1ddc78fcc3df8ec5af21da20db492c315c96`
- Evidence-only commit: the commit containing this manifest

The tracked log files are curated command/result excerpts. Complete raw console output was not captured to standalone files and is therefore unavailable as a separate artifact; it remains in the R23 acceptance task transcript. Browser screenshots likewise remain inline in that transcript. The summaries do not claim to be reconstructed raw logs.

The production build artifact applies to source commit `df632e57a4d8255dcfd5fa1d8ac93aa124164536`. Per root instruction, the build was not rerun merely to capture output after the bounded root-review correction. Final source commit `190945e2` is covered by the 105-example backend suite, focused 8-test Vue suite, ESLint, RuboCop, reversible migration check, and diff/lockfile checks recorded in `review-remediation-tests.log`.

## SHA-256

```text
b16ca4448b2fe9866936457284986e9f61cd7e325806c2fe55e892dadcddf46c  README.md
397259dad615dcb906bbf83fedc08a652d95a63c13d76c8fd0eb6219564a0ebd  backend-tests.log
b8111f0b32ce33840e9b9ac10d78a25199e0028448a1884a8a60890facc14a01  frontend-tests.log
19e6a5e2f1f2423616846573078a4e5f65b23bd7712cb557a4445b68fcca933f  production-build.log
cc4d5ddc6a6d6c0d0f6e0ee304c01821532cb307c970f979e4efceb715cc99d8  migration.log
c72105680db992c5e6a3aa3bd1899432f747db3b14e85daa0aeeeddfbb9abc34  review-remediation-tests.log
20101851e36dec63974304fa75b13b181578191b25897c3111b3bbe0f7dacc90  browser-acceptance/README.md
```

`EVIDENCE_MANIFEST.md` is intentionally not self-hashed.
