# Verification

All Rails verification in this correction series after the disclosed initial
mistake used the dedicated PostgreSQL database
`r11_source_concurrency_test` with placeholder test encryption keys.

## Final source results

- Exact six-regression delta for repeated configured names and bounded courtesy
  tails: **6 examples, 0 failures**.
- Affected classifier and R11 intent-processor specifications at exact source
  commit `2d44916c4d09e8150e5773dca23c4c8d3a9f13c4`: **253 examples,
  0 failures**.
- The immediately preceding complete focused seven-spec bundle: **266 examples,
  0 failures**.
- The immediately preceding complete impacted fifteen-spec Rails bundle:
  **325 examples, 0 failures**.
- Source concurrency specification at the preceding source candidate:
  **3 examples, 0 failures**. It used
  `R11_SOURCE_CONCURRENCY_DATABASE=r11_source_concurrency_test` and
  `R11_SOURCE_CONCURRENCY_ALLOW_TRUNCATE=1`. It was not rerun for the final delta
  because that delta changed only parsing, polarity handling, and their examples;
  the coordinator explicitly excluded an unchanged concurrency rerun.
- Commercial-claim validator and destructive-database guard: **12 examples,
  0 failures** earlier in the correction series. Those files were unaffected and
  were not rerun in later bounded intervals.
- RuboCop across all **30** source and specification files changed from correction
  base `c91767a66ee25cbcb56b025f2b2b3d25d37eadc9`: **0 offenses**.
- `git diff --check`: clean.
- Normal repository commit hooks: passed without bypass.
- Mandatory specification review of the exact source commit: **CLEAR**.
- Mandatory engineering-standards review of the exact source commit: **CLEAR**.

## Test-driven correction history

The first focused run reported **187 examples, 2 failures**. Completion discarded
the extracted question's scope-resolution provenance, and the external-subject
grammar missed `What does [subject] cost?`. The implementation fixed both. Their
targeted retry passed at **2 examples, 0 failures**, followed by complete focused,
impacted, and concurrency results of **187/0**, **246/0**, and **3/0**.

The next candidate's first focused run reported **198 examples, 1 failure** because
the conjunction retrieval fixture used `Health and Wellness`; the medical-risk
policy intentionally intercepts `health` before knowledge lookup. Exact extraction
and classification remain covered with that name, while retrieval uses `Growth and
Wellness`. The targeted correction passed at **2/0**, followed by **199/0** focused,
**258/0** impacted, and **3/0** concurrency results.

The following candidate's first focused run reported **214 examples, 3 failures**.
Two failures corrected expectations while preserving policy: a Swahili denial
returns the Swahili boundary, and a direct `Bei` question remains a risky pricing
question while compound extraction and provenance are asserted separately. The
third exposed a real modal-name fallback gap, which was fixed. The targeted retry
passed at **3/0**, followed by **214/0** focused, **273/0** impacted, and **3/0**
concurrency results.

The next source candidate added copular named-subject questions, productive
Swahili report-stem exclusion, arbitrary-length configured subject phrases,
polite-tail polarity, symmetric uncertainty, shared Swahili question/language
signals, and Swahili-only retrieval provenance. It passed **227/0** focused,
**286/0** impacted, and **3/0** concurrency without an intermediate failure.

The next broader diagnostic selection reported **253 examples, 4 failures**. One
was a real missing productive `vingapi` form; three exposed punctuation-format
regressions. Their targeted retry passed at **4/0**. The exact seven-file focused
selection then passed **243/0**, the impacted selection passed **302/0**, and the
concurrency specification passed **3/0**. The diagnostic count was larger because
it selected additional examples beyond the exact seven-file focused bundle; it is
recorded separately and is not presented as a focused green run.

The next candidate's initial focused run reported **253 examples, 9 failures**.
Seven came from overbroad whole-message protection around conjunction-bearing
names, and two came from expectations that incorrectly required a
scope-resolution decision for direct Swahili questions. Protection was narrowed
to the exact configured-name span. The direct-question examples now assert the
actual contract: classification, language, and current-message Review provenance.
The nine-example retry passed, followed by **253/0** focused, **312/0** impacted,
and **3/0** concurrency results.

The next candidate passed **261/0** focused, **320/0** impacted, and **3/0**
concurrency without an intermediate failure. Its successor added five exact
regressions, which passed **5/0**, followed by **266/0** focused, **325/0**
impacted, and **3/0** concurrency results without an intermediate failure.

Exact review of commit `6a325896a1a2b53dd2f772b529a72fe5e9c081ad`
then found that configured-name boundary protection considered only the first
matching occurrence in a clause. The final delta enumerates every occurrence and
also bounds multi-word English and Swahili terminal courtesy clauses. Its six new
examples passed **6/0**, and the two affected specification files passed **253/0**.

Earlier in this correction series, the first lock-order regression exposed a
deadlock in an intermediate implementation. The final implementation moved the
answer boundary to authority, Account reference, then Conversation order; the
three-example concurrency suite passed afterward.

An earlier impacted-suite run exposed a date-sensitive booking-list assertion: on
Sunday, the factory's `1.day.from_now` booking fell exactly at the default range's
exclusive Monday endpoint. The request now supplies an explicit range. Its focused
retry and complete impacted reruns passed.

## Acceptance ownership

No broad build or browser run was performed during this correction series. R26
owns combined acceptance, and R23's earlier supervised browser acceptance remains
separate from this source correction.
