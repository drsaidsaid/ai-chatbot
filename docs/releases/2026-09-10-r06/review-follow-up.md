# R06 alternative-path review evidence

Status: three confirmed coordinator findings fixed and regression-tested.
Browser acceptance is still pending Mac unlock; no new browser proof is claimed.

## Reproduced failures

- Macro HTTP: an authenticated request returned the macro list instead of V1
  unavailability. The fixed request test exercises index/show/create/update/delete/
  execute for both roles and confirms that no execution job is enqueued.
- Legacy macro queue: a Team Member's queued personal macro created an unauthorized
  Message in an inaccessible Conversation. The fixed job test confirms no message,
  no self-assignment and no disclosure webhook. Demotion/revocation after enqueueing
  also stops execution; an authorized Admin positive path remains account-scoped.
- Lead merge: a Team Member received 200 for merging an inaccessible Lead into an
  assigned one. It now receives 401, leaving both identities and hidden attributes
  intact. An Admin can merge within the account; a foreign target returns 404.
- Bulk labels: a contact reassigned before the job ran still received a label.
  The job now labels only currently visible contacts. Removal, membership
  revocation and cross-account IDs are covered.
- Bulk deletion: demoting the queued Admin still deleted their assigned contact,
  making a subsequent authorized GET return 404. It now remains readable (200).
  Revoked membership also stops deletion; current Admin deletion still works.

## Final combined regression

Run with the documented isolated R06 test environment:

```sh
bundle exec rspec spec/requests/r06* spec/jobs/r06* spec/controllers/api/v1/accounts/macros_controller_spec.rb spec/controllers/api/v1/accounts/actions/contact_merges_controller_spec.rb spec/controllers/api/v1/accounts/bulk_actions_controller_spec.rb spec/jobs/contacts/bulk_action_job_spec.rb spec/services/contacts/bulk* spec/services/macros/execution_service_spec.rb
```

Result: **79 examples, 0 failures** (50.92 seconds; 6.71 seconds load).
This includes the prior R06 request/job regressions, real media rendering,
invitation acceptance, first assignment, and queued realtime/notification scope.
The narrower initial new-path run passed 14 examples before the combined run.

Ruby lint: **11 files inspected, no offenses detected**. Whitespace checks pass.
The existing production Vite build remains applicable: this follow-up changes
only Ruby, tests and documentation. No new heavy build was started.

`source-manifest.json` contains SHA-256 hashes of every changed app/config file
against the integrated R01/R02 base. The schema, lockfiles, license, enterprise
source and frozen audit files remain unchanged. Runtime fixtures are isolated;
no external message, webhook or provider delivery was performed.
