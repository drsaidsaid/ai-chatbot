# Attempt and preparation seam — development checkpoint only

This source implements the migration, immutable artifact scheduling/replacement
and ordered preparation. Canonical dispatch outcomes and callback batches still
require migration to the accepted lock matrix. Do not release this mixed state.

Prior red source:33631e3db14176d5fb81a093648ef74e4d143230,12 examples/12 failures.
A subsequent12/1 run exposed a test fixture's stale version on its second Offer
edit; preserving the successful response version corrects that fixture without
weakening the lineage assertion. The corrected27-case seam suite passed once.
Frozen-source reproduction follows.

Frozen source750bfd6cefd1912c71cb49da04c7d8c15fd82036 reproduced27/0 with
whole-tree equality before/after. Manifest8947 non-release paths;72 changed
runtime/test paths against9a. No provider HTTP, build, lint, hooks or deployment.
