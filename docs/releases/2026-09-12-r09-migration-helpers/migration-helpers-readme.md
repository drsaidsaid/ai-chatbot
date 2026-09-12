# R09 historical migration helper cleanup

Source: `2e5e59529acd2103b873549a50050b6605a15c50` (`refs/r09/migration-helpers-green-source-20260912`). Before: `cc45f2b77b8e9dee9b7db7accde85171be2f6190`.

Extracts the revision table creation and ordered lineage migration phases into private helpers. SQL whitespace is squished without changing literals, predicates or statement order. No new migration or historical outcome changes.

24 affected Rails examples passed, zero failures/pending. Separate original/candidate runs in transaction-isolated schemas compare columns/defaults/nullability, indexes, foreign keys, check constraints and all migrated rows. All eight evidence signal values and 72 lineage cases (provider state × follow-up status × message source) match. Offer migration reversal and the two explicitly irreversible migrations retain their outcomes. No comparison schemas remain. Both runs verify the complete source tree before and after.

Full required changed-path lint: 16 findings across 97 inspected files; all three migration files are clean. Remaining findings belong to delivery authority/outcome/handoff/consent. Earlier full regression/build results are not attributed to this source.

Included original migration backups, comparison harness/results, immutable source identities, full manifest and exact source diff. Root migration review remains required before consolidation. No deployment or integration performed.
