# R09 Offer UI completion

The coordinator accepted full source `1ede019dfa15f62b6d2ac3da4ffb106f642ac42d`
as the delivery increment 2 development checkpoint, not full R09 acceptance.
The 246-example broad run on the preceding source and 57-example affected run
on that checkpoint remain separate evidence.

## Remaining acceptance path

1. In the existing Offers and qualification settings route, configure each
   Offer's typed questions, ordering, required/enabled state, labeled currency
   amounts, budget ranges, bounded rules, score thresholds and revision.
   Preserve decimal strings, report validation/conflicts, and retain drafts on
   errors. No implicit legacy migration.
2. Carry explicit Offer selection through existing Leads filters/detail/export.
   Show Offer identity, evaluated/current revisions, stale/legacy state,
   evidence polarity and provenance, missing signals and next question/action.
3. Add a qualification-only Conversation component using existing scoped read,
   evidence and selection APIs. Preserve R06 complete-contact access and every
   R07 control/action/event behavior. No campaign routing or R11 retrieval work.
4. Test saved settings through canonical incoming-message qualification and
   scoped readers; verify Vue behavior, relevant Rails regression, lint/build,
   and the in-app browser when the coordinator allocates browser/server time.

## Agreed seams and coordination

Behavior tests exercise the Vue settings form against its HTTP client boundary,
Lead query/detail/export behavior, Conversation Offer selection/corrections,
and existing canonical request specs for incoming-message qualification.
Use the existing Rails/Vue baseline and components-next conventions.

Shared files for root integration review: AiLeadEmployeeSettingsShell.vue
(Offer placement only), LeadsDirectoryPage.vue, LeadDetail.vue,
AIEmployeeControlPanel.vue (additive qualification slot), and English
aiLeadEmployee.json. Read R07 candidate
`f65cf3852c652ffd37fa705191ce85305c67cc93` before choosing the Conversation slot;
do not import it or change control state/actions/events. Preserve existing
provider settings, shell/navigation and access/filter/export boundaries.

The first focused Vue/API runtime interval is allocated for at most 20 minutes
after tests are prepared. Report release or a concrete extension need. Final
build/server and in-app browser ownership require a separate coordinator
allocation; the prior Mac lock blocker needs a fresh check. Complete checks
and source review before a normal ticket commit. Only root integrates/deploys.
