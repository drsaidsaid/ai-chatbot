# R23 evidence manifest

- Final verified source commit: `e0bbd23ea109f71e73f725cacf382d398ea25acd`
- Final verified source tree: `f15b183eea722340ceb60b437a744a9e7d1f1997`
- Evidence-only commit: the commit containing this manifest

The tracked log files are curated command/result excerpts. Complete raw console output was not captured to standalone files and is therefore unavailable as a separate artifact; it remains in the R23 acceptance task transcript. Browser screenshots likewise remain inline in that transcript. The summaries do not claim to be reconstructed raw logs.

The production build artifact applies to final source commit `e0bbd23ea109f71e73f725cacf382d398ea25acd`. The complete R23 suite passed with 111 examples at `4ca8b6ef`; the final lock-order and migration follow-up is covered by the 43-example changed-path suite at `e0bbd23e`, focused 8-test Vue suite, ESLint, RuboCop, reversible `00500` migration check, browser acceptance, and diff/lockfile checks recorded in the evidence files.

## SHA-256

```text
e89aafb1609eaa8f13a15e8f2e460a0635cce2c2e590f0e005361ef080165f85  README.md
397259dad615dcb906bbf83fedc08a652d95a63c13d76c8fd0eb6219564a0ebd  backend-tests.log
b8111f0b32ce33840e9b9ac10d78a25199e0028448a1884a8a60890facc14a01  frontend-tests.log
3144d91166c4cc62b9216b936952cfb710914d1f81af4f32c6d425e09fc45b7b  production-build.log
cc4d5ddc6a6d6c0d0f6e0ee304c01821532cb307c970f979e4efceb715cc99d8  migration.log
44f02e45e52b5c0d0f5f32dd38cb88ac2fe647c8812ed44e899efdea23fac105  review-remediation-tests.log
a6a6d30c2575211350bf202bfb7930ef25b96719154288d3539480786d2388b0  browser-acceptance/README.md
```

`EVIDENCE_MANIFEST.md` is intentionally not self-hashed.
