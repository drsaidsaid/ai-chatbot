# Intentional red run

Command:

```text
pnpm exec vitest run app/javascript/dashboard/routes/dashboard/owned/specs/LeadsDirectoryPage.spec.js --reporter=dot
```

Result: 15 tests ran; 12 passed and the three new account-state tests failed.

- A delayed preview from account 1 opened after navigation to account 2.
- An old account apply prevented or erased the account 2 preview.
- A closed apply erased a newer preview when the old request completed.

The full output was displayed by the test runner but was not redirected before execution, so this file preserves the contemporaneous failure facts rather than claiming to be a verbatim log.

