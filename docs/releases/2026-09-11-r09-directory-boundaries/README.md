# R09 Offer booking filters and effective sort

The shared Lead directory now applies the explicit Offer scope to every booking
filter: confirmed/booked, no_booking, canceled and completed. Without an Offer
selection it ignores booking filters and returns neutral booking rows. This aligns
filter membership with the already scoped row payload. A shared effective_sort
method now governs both ordering and pagination metadata, including last_contact
fallback when quality/score sorting is requested without a selection.

The new request spec exercises real A/B bookings for the same Lead, another Lead
without a booking, all neutral booking filters, and actual row ordering plus sort
metadata. Original reader, human/legacy edit, lifecycle and R06 tests remain intact.
The corrected fixture RED run is10/10 at immutable
98b8eb3271f40f13ac8b302a378c672b01edb319,
refs/r09/directory-boundaries-red-20260911. Prior exact49/0 reproduction on
becb6fc remains preserved; these two new gaps were outside those49 assertions.

All tracked/nonignored source is frozen using automatic full-index enumeration,
including unchanged dependencies and every changed runtime/schema/config/spec
path relative accepted9a. This source freeze precedes the combined59 reproduction;
whole-tree equality will be checked before and after, with results appended in a
separate evidence freeze. No delivery, schema, R06 policy or R07 control/event
implementation changes are part of this correction.

## Verified result

**59 examples, 0 failures** on complete source tree
e7601952e2fc3cc8ebeac8d666f95a58e4ac14ea,
refs/r09/directory-boundaries-source-20260911. Full repository tree equality
passed both before and after execution. The manifest covers every8936 non-release
repository file, including all52 changed runtime/test paths and all unchanged
baseline dependencies. Directory blob is
b0c0df48f45585a424f3ff9f5e0c6fc5cbf02690. Relative to complete becb6fc, runtime
changes are confined to that service and the new boundary request spec.

The59 comprise boundary10 plus shared readers12, Offer legacy edits2, human
boundaries7, lifecycle13, and existing Lead edit/directory/R06 compatibility15.
The suite used global Ruby3.4.4 gems, no install, with BUNDLE_PATH, BUNDLE_GEMFILE,
GEM_HOME and GEM_PATH unset, preserving the dedicated synthetic test environment.
Exact files passed to bundle exec rspec:

- spec/requests/ai_lead_employee/offer_directory_filter_boundaries_spec.rb
- spec/requests/ai_lead_employee/offer_shared_readers_spec.rb
- spec/requests/ai_lead_employee/offer_legacy_lead_edit_spec.rb
- spec/requests/ai_lead_employee/offer_evidence_edit_boundaries_spec.rb
- spec/requests/ai_lead_employee/offer_evidence_lifecycle_spec.rb
- spec/services/ai_lead_employee/lead_update_service_spec.rb
- spec/services/ai_lead_employee/leads_directory_service_spec.rb
- spec/requests/r06_assigned_access_spec.rb

The test interval is released: PostgreSQL55519 and Redis6421 stopped successfully;
listener check returned no listeners. No build/browser/hooks/commit/deployment
was run. Final delivery implementation remains blocked pending coordinator
review. ADR0015 includes the reviewed caller matrix and batch lock clarification.
No delivery implementation or historical exact-bd6 run equivalence is claimed.
The original incomplete snapshots, corrected49 reproduction, and RED boundary
source/evidence remain retained and unchanged.
