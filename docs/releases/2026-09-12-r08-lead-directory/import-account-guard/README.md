# R08 import account-state guard evidence

- Source commit: `da465f7bc28a44793faabd555a30f08b1af8b32b`
- Parent: `f371bdc8c1cd2f13fed5b4ed7b1644cbd71ab33d`
- Source tree: `305a51fb05516e5fe89e7cc98e1cd4a87d51390b`
- Changed paths: `LeadsDirectoryPage.vue` and its component spec

The correction binds each import preview or apply request to an operation number and the current account. Account transitions invalidate the operation, clear file/preview/modal/message/busy state, and prevent stale success, failure or finalization writes. Apply also checks that the visible preview belongs to the current account. Closing an import invalidates its request so a later preview cannot be erased by the old completion.

`red-observation.md` records the intentional failing test run. `vitest-green.txt` and `eslint-green.txt` are exact final focused outputs. The five `source-tree-*.txt.gz.base64` files partition the complete committed `git ls-tree -r` inventory. `correction.diff.gz.base64` is the complete parent-to-source diff. Evidence validation compares decoded artifacts to Git.

Browser acceptance remains pending because the Mac is locked. No server or alternate browser was used.
