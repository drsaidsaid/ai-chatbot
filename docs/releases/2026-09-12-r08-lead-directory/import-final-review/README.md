# R08 import final review correction

- Source commit: `d81c9e4f12b3ebacce69e7e917efb47b8a14fed3`
- Parent: `918d4af0489fc3a00d95d43465155090e29b50c1`
- Source tree: `943b6a91e4af3d47fcc6eb2cdd1d1ed2c7ddff02`

Retry-later translation is scoped inside pre-commit apply work. A matching
database exception raised by `after_commit` propagates and cannot misreport the
durable Contact as a retryable rollback.

Preview and apply identity resolution now load phone and email matches in at
most two account-scoped queries for the complete 100-row file. During apply each
bulk query refreshes PostgreSQL statement timeout to the remaining cooperative
budget. Row writes remain cooperative units checked before and after each row;
the implementation does not claim a hard whole-transaction wall-clock cap.

The draft ADR calls this an implemented import-owned candidate under review. It
does not accept the system-wide identity design or the full R08 ticket, and it
retains the waiting-writer limitation documented in the preceding checkpoint.

The five source-tree artifacts partition the complete committed Git tree and the
diff artifact covers the complete parent-to-source change. Browser acceptance
remains pending because the Mac is locked.
