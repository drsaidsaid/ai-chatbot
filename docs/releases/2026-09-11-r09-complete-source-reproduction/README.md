# R09 complete source reproduction correction

The historical shared-readers tree bd6e54aae5a7e6d2b3405d29528e63488879380d
and delivery-red tree 374fca9fb372f30a6e7f04eba39228723b734774 omitted the modified
LeadsDirectoryService. Both contain baseline blob
6013e981e6c9a347b48c1f02e314e458d90db3c4. The live tested service is blob
3f635331716a69b2940499b6bd0e13553d6e1d40. The selected-path manifest omitted
the service, and the isolated snapshot index retained its baseline content.
The ordinary index is empty; the working implementation was not lost.

The earlier 49/0 and delivery 9/7 results are observed working-folder runs,
not proof of exact bd6 runtime behavior. The earlier attribution is retracted.
All old refs, metadata and raw logs remain intact as historical incomplete
snapshots. No production or test changes were made for this correction.

The replacement source snapshot is generated from all tracked and nonignored
files using a separate index seeded from accepted base
9a834e756347822d4ae5af15f268a5e8751fc852, followed by git add -A. No selected
runtime allowlist is used. Every changed/new/deleted path relative to the base
is enumerated automatically. All repository source, tests, configuration,
lockfiles and unchanged baseline dependencies are retained. Ignored files
were enumerated: only generated tmp/ and log/ files exist in this worktree.
Synthetic test environment and cached installed gems remain external runtime
inputs; secrets are not published. No enterprise source is introduced.

Whole-tree equality is checked before and after reproduction using the same
complete-index procedure; no source changes are allowed during the run.
The final evidence snapshot adds only this release's documentation and logs.
Results and exact identities are recorded after execution.

## Observed reproduction

Exact full source tree becb6fc4d243204ee6a872dd4d71b493f07b0580 at
refs/r09/shared-readers-complete-source-20260911 passed whole-tree equality
before and after the reader compatibility run: **49 examples, 0 failures**.
The run includes shared readers12, legacy Offer edits2, human edit boundaries7,
lifecycle13, and existing Lead edit/directory/R06 compatibility15. Both equality
reports and the raw result are retained in evidence/. The copied snapshot helper
shows the complete index procedure. No production/test file changed during the run.

Two earlier launches stopped in Bundler before executing any examples because
the old /tmp/ale-r01-gems.HdwFNm directory no longer exists. Those logs are kept
separately. The successful run used existing global Ruby3.4.4 gems with
BUNDLE_PATH, BUNDLE_GEMFILE, GEM_HOME and GEM_PATH unset; bundle check passed.
No dependencies were installed. The original dedicated PostgreSQL55519,
Redis6421, test database and private synthetic environment were retained.

The historical delivery9/7 run is not rerun in this reproduction; its observation
is retained with corrected attribution to the then-live working folder, whose
complete identity was not captured. A current full runtime diff against bd6
shows only the missing directory service, but this is not claimed as retrospective
proof of every file at the historical run. Delivery implementation remains blocked.

Review of the now-included directory implementation found separate booking-filter
Offer scoping and effective-sort metadata issues. Those are not covered by this
49-example success and will be corrected in a subsequent separately frozen slice.
The source tree and this reproduction evidence remain immutable.
