# Issue Tracker: GitHub

Issues, specifications, Wayfinder maps, and implementation tickets live in this
repository's GitHub Issues. Use the `gh` CLI from the repository root.

Create issues with `gh issue create`, read them with `gh issue view <number>
--comments`, and close resolved issues with `gh issue close <number> --comment`.

## Wayfinding Operations

A Wayfinder map is one issue labelled `wayfinder:map`. Its decision tickets are
child issues labelled `wayfinder:research`, `wayfinder:prototype`,
`wayfinder:grilling`, or `wayfinder:task`. Add native GitHub blocking links when
available; otherwise state `Blocked by: #<issue>` in the ticket body.

Claim a decision ticket before working it with `gh issue edit <number>
--add-assignee @me`. Resolve one decision ticket per session: comment with the
decision, close it, and link it from the map's Decisions so far section.

Pull requests are not a triage surface for this repository.
