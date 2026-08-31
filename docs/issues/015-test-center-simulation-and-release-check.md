# Test Center Simulation and Release Check

Status: Done

## What to build

Create Test Center as the workspace for scenario simulation, result review, and
release checks before configuration changes affect real Leads. The completed
slice must run scenarios without sending WhatsApp messages and expose the AI
Employee decision trail clearly enough for admins to approve or block launch.

## Reference screen

- Test Center:
  `/Users/ghalyasaid/.codex/generated_images/01a03d53-397a-71b3-8f20-3fa5f610599f/exec-5c2eb3e9-c97b-41cd-b6ac-5bdbecb288b8.png`

## Acceptance criteria

- [x] Test Center top-level navigation opens a workspace with working Scenarios,
      Results, and Release check tabs.
- [x] Scenarios tab includes search, Offer filter, Result filter, Owner filter,
      more filters, scenario table, selected scenario panel, and Run test action.
- [x] Running a scenario never sends a real WhatsApp message, creates no live
      provider side effect, and clearly marks the transcript as simulation.
- [x] Scenario transcript uses the WhatsApp-like message layout from the
      reference and shows lead messages, AI Employee replies, timestamps,
      selected answer source, extracted evidence, Lead Quality, score, next
      question, handoff decision, booking decision, review/refusal behavior, and
      delivery simulation state.
- [x] Evaluation criteria show pass/fail/needs-review results for approved
      answer use, qualification question behavior, invention avoidance, next
      step, Lead Quality, booking eligibility, handoff eligibility, tone, and
      safety.
- [x] Test summary records total checks, tester, run time, configuration
      version, knowledge version, model identifier, expected result, and actual
      result.
- [x] Results tab supports filtering historical runs by scenario, owner, result,
      Offer, configuration version, knowledge version, and date.
- [x] Release check tab summarizes the launch gate from ticket 009, including
      qualification accuracy, handoff accuracy, unanswered-question rate,
      booking outcomes, serious safety failures, and admin approval state.
- [x] Incorrect messages can be marked wrong, corrected, and optionally proposed
      to Knowledge without bypassing approval.
- [x] Every link, tab, form, filter, transcript control, dropdown, toggle, and
      action introduced or touched by Test Center is keyboard-reachable, has a
      visible state, and routes or persists through existing Rails/Vue
      conventions.
- [x] Realistic states include passed, failed, needs-review, never-run, running,
      cancelled, stale configuration, failed model call, no scenarios, and no
      results.
- [x] Rails request/service specs cover simulation isolation, scenario CRUD if
      implemented here, run persistence, grading, release-check aggregation,
      tenant scoping, authorization, and no live Meta/calendar/alert side
      effects.
- [x] Vue tests cover tabs, filters, run button states, transcript rendering,
      criteria grading, summary actions, error states, and long-message
      wrapping.
- [x] Browser QA covers running a scenario, reviewing results, grading,
      proposing corrected knowledge, opening Release check, and mobile access
      through More.
- [x] A same-viewport screenshot at 1536 x 1024 is compared with the reference
      and documented as faithful within the visual tolerances; mobile behavior
      is checked at 852 x 1846 and 390 px widths.
- [x] `docs/issues/015/design-qa.md` exists with `Result: Passed`, screenshots,
      viewport dimensions, zero-overlap notes, and accepted deviations.

## Blocked by

- Ticket 009: Evaluation sandbox and launch gate.
- Ticket 010: Conversation Cockpit navigation and responsive shell.
