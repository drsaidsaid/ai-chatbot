# R08 bounded export checkpoint

- Source commit: `41fcd0055719f73ad1f5aeca7e7719d4baf755e3`
- Parent: `cee928cf6c38c054c8e6fb6a3f2e256be4193bce`
- Source tree: `4856d9a9dd2d1ac63f507cebe3938c0d96d89e7d`

The controller returns lazy CSV lines. Enumeration resolves fresh AccountUser,
Account and User records without `Current`, requires an administrator, and runs
inside a repeatable-read snapshot in production. The directory fetches ordered
IDs in batches of 250 and preloads only the one-row-per-Lead context used by CSV.
Every supported sort includes an ID tie-breaker.

The five source-tree artifacts partition the complete committed Git tree.
`source.diff.gz.base64` is the complete parent-to-source diff. Validation decodes
and compares both artifacts with Git. Browser acceptance remains pending because
the Mac is locked.

