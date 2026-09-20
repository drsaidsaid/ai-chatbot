# R19 natural conversation and plain-language setup — implementation plan

Status: coordinator-reviewed implementation direction, 20 September 2026.  This plan implements the
owner correction in [r19.md](r19.md), the
[natural-conversation audit](NATURAL_CONVERSATION_AUDIT_2026-09-20.md), and the
owner-observable acceptance matrix in
`local/pilot-readiness/NATURAL_CONVERSATION_ACCEPTANCE.md`.  It does not
authorise a provider call, deployment, customer send, schema migration, or a
change to payment, delivery, consent, tenancy, or human-control authority.

## The problem and the intended shape

The current implementation has reliable, versioned Offer configuration and
evidence, but it treats the next missing *required* configuration field as the
next literal question.  `OfferQualificationService#next_question` selects by
required flag and stored order.  `SafeConversationReplyService#useful_next_question`
then appends that prompt for greeting, acknowledgement, strategy, and
qualification-answer intents.  The local safe-reply path does not localize it.
This is the direct cause of a Swahili greeting becoming an English revenue
interview.  In the real 135/136 case, the money revenue and text goal observations were also
rejected as `typed_mismatch`; prompt wording cannot make the stored evidence
reliable by itself.

The replacement is one deep module at a single seam:

```
inbound message + approved Offer + source-linked evidence + intent/knowledge result
                                  |
                                  v
                        ConversationTurnPlanner.plan
                                  |
          reply purpose, one optional follow-up, outcome candidate, explanation
                                  |
                                  v
  Safe local reply / grounded provider reply / handoff-review-outbox, unchanged authority checks
```

Its interface returns a small immutable turn plan, rather than allowing each
reply path to append a question.  Its implementation owns relevance, supplied
facts, sensitivity, language, and one-question selection.  `OfferQualificationService`
continues to calculate evidence, configured rule assessment, score, and
missing requirements; it stops being a conversational scheduler.  This gives
one test surface and prevents an equivalent fixed script emerging in the
provider-free, grounded-answer, and progression paths.

## Current capability versus required change

| Area | Present capability | Required R19 correction |
| --- | --- | --- |
| Setup/review | `OfferConfigurationPanel.vue` creates versioned `BusinessSetupSource` proposals, shows facts/rules/unknowns/history, and publishes with offer/source optimistic versions. | Recompose this same route into the six owner sections below; make question text suggested wording and hide machine controls by default. |
| Commercial authority | `Offer` commercial-term draft/publish/preview endpoints are the sole published price path. | Keep them sole authority; surface them in **Offers and prices**. No prose extraction or conversation can override an inactive/quote-required price. |
| Qualification | `OfferQualificationService` writes current `QualificationEvidence`, snapshots, assessment, reasons, missing fields and handoff eligibility. | Keep deterministic assessment; split current revenue from desired revenue, obstacle, fit, readiness, and agreement into owner-defined fields, and replace ordered prompting with contextual selection. |
| Conversation | `IntentProcessor` classifies, retrieves approved knowledge, validates provider output, records observations, creates reviews/handoffs, and uses canonical outbox delivery. | Route every non-human/stop reply through one turn plan. Answer approved information first; ask zero or one useful follow-up only when appropriate. |
| Language | Classifier detects Swahili and the structured provider path can localize a prompt. Local safe replies are localized but appended owner prompts are not. | Persist requested conversational language in the existing scoped conversation context and render both local acknowledgement and selected suggestion in that language. Never append an untranslated stored prompt. |
| Preview | `EvaluationSandboxPanel`/`SandboxRunner` execute one scenario in a rollback transaction using orchestration, with no real send. The Offer page test is one question against a current published source. | Add multi-turn configuration-scoped conversation preview and owner explanation: remembered evidence, unknowns, fit/readiness, outcome candidate, source/revision, authorization/cost state. Label simulation separately from approved owner-only live verification. |
| Outcomes | `OfferProgressionService` has one `next_step`: answer-only, enquiry, purchase link, sales call, or appointment. | Add a reviewed conditional outcome policy only after the ADR gate below: ready+agreement sales queue; interested/not-ready approved resource if eligible; no relevant interest polite close. Missing URL means no invented link/invitation. |

## Owner setup: one route, six sections

Keep `/app/accounts/:accountId/settings/ai-lead-employee` and
`OfferConfigurationPanel.vue`; do not create a competing editor.  The first
screen must be the following progression, with existing source/revision state
visible but secondary:

1. **About the business** — plain business description and pasted/document
   source; proposed approved facts, unknowns, source history, corrections.
2. **Offers and prices** — existing published commercial term summary, draft,
   effective dates, conditions and approved URL.  Quote-required remains an
   explicit published state.
3. **Who we help** — optional information requirements and plain-language fit,
   readiness, and agreement preview.  “Suggested wording” replaces “Question
   to ask”; no promise that questions are asked in order.  `not_configured`,
   `disabled`, and `enabled` remain explicit.
4. **How the assistant should respond** — approved knowledge/source scope,
   language/tone suggestion, answer-first behavior, and what to do when
   information is unknown.  It must say a review request is created, not
   promise a callback.
5. **What happens next** — existing answer/enquiry/purchase/appointment
   controls plus the ADR-approved outcome policy when available.  Show the
   actual approved resource/link or state that none is configured.
6. **Preview and publish** — reviewable proposed facts/rules/unknowns, draft
   versus live revision, unsaved/conflict state, multi-turn preview, then
   deliberate source/Offer publication.

An **Advanced technical controls** disclosure contains keys, answer types,
currencies/periods, score weights, required flags, positions, and nested rule
operators.  Validation and the owner-readable rule summary remain present;
moving controls does not weaken the data contract.  The existing source and
Offer expected-version locks remain the publication authority.  “Edit
published” continues to seed a proposed source, never silently changes live
configuration.

## Conversation policy and evidence

`ConversationTurnPlanner` receives only approved configuration, classified
intent/language, current source-linked evidence, knowledge-answer result, and
the deterministic assessment.  It returns: `reply_kind`, an optional
`suggested_follow_up_key`, an owner-visible reason, an outcome candidate, and
the language.  It has these invariants:

- Greeting, stop, and human-request paths never select financial, budget, or
  sales-call questions.  Stop/takeover continue through their current
  deterministic controls before planning.
- A factual business question is answered from approved knowledge before any
  follow-up.  An unknown relevant question creates the current Review Request
  and receives only a truthful acknowledgement, never an appended interview.
- It selects at most one enabled, unsatisfied, relevant
  information requirement. Financial questions require appropriate business context;
  they are not prohibited once relevant to the approved Offer and conversation.  Existing asserted evidence and correction history
  suppress repeat questions; optional goal/obstacle information can be useful
  without becoming a forced gate.  Requiredness remains assessment/action
  semantics, not utterance order.
- Current state, desired goal, obstacle, readiness, and explicit agreement
  are distinct configured fields.  The evidence recorder/typed validator is
  the sole writer; a correction supersedes the current fact using existing
  evidence lineage, then assessment is recomputed.  Ambiguity requests
  clarification rather than accepting an invented typed value.
- The planner chooses a local language rendering for every locally generated
  reply.  It may use provider localization only as a rendering adapter, never
  as authority to invent facts, eligibility, a URL, or a rule.
- It returns an outcome *candidate* only.  `OfferRules`, handoff permission,
  agreement evidence, source/version locks, Review Request, canonical outbox,
  usage reservation, provider-cost recording, and delivery confirmation remain
  the final authorities.

The planner does not own evidence persistence, rule evaluation, knowledge
retrieval, or sending.  That preserves the existing tenant/account/contact/
Offer scope and keeps provider-free behavior deterministic and testable.

## ADR gate before outcome-policy code

ADR 0016 authorizes optional qualification and one configured next step, but
does not define a conditional nurture/resource/community policy.  Before any
schema, API, or UI implementation of this policy, record an ADR 0016 amendment
that decides all of the following:

1. The reviewed, versioned Offer representation for conditional outcomes and
   eligibility (including whether it is a new Offer-owned revision or an
   extension of `next_step`).
2. The distinction between a resource invitation, community invitation, human
   assistance, enquiry, sales-call eligibility, and appointment; none may
   imply enrollment or a send.
3. URL/source authority, missing-resource behavior, effective/revoked
   configuration, and the exact deterministic precedence with existing
   sales-call agreement and human/stop controls.
4. Whether an outcome candidate is evidence-only, an owner-visible suggestion,
   or may create an existing queue; no new autonomous delivery authority.

Until that ADR is accepted, use the existing configured `next_step` and a
truthful missing-resource result.  Do not hardcode an Online Profits resource,
price, sales call, or universal revenue gate.

## Small dependency-ordered slices

1. **Policy seam and regression characterization.** Add the pure turn planner
   and move local/grounded/progression question selection behind it. Keep data
   shape unchanged. Cover greeting, knowledge answer, unknown, human/stop,
   correction, and disabled/not-configured Offers.
2. **Evidence correctness.** Characterize the actual Swahili multi-fact and
   correction strings; correct typed parsing/validation or the field contract
   so `800,000 TZS per month` and `3,000,000 TZS goal` persist separately with
   source evidence. Do not relax quote/currentness/currency/period validation.
3. **Language and owner explanation.** Persist/render language across all
   reply paths and expose planner explanation/evidence/unknowns/assessment in
   the existing conversation cockpit without exposing private provider prompt
   or raw diagnostics.
4. **Six-section Offer page.** Reorganize the existing Vue route, add the
   Advanced disclosure, and preserve every current draft/live/conflict/source
   and commercial control.
5. **Multi-turn preview.** Extend the existing rollback sandbox and Offer test
   affordance to run a configuration-revision-scoped sequence through the
   same orchestration path, show each turn plus owner explanation, provider/
   cost/authorization state, and no-send proof.
6. **Conditional outcomes.** Only after the ADR amendment, add the reviewed
   configuration, deterministic resolver, UI, preview, and queue/read-model
   coverage.  This is deliberately last because it changes product authority.

Each slice is independently reviewable in R19 and can be stopped without
changing published behavior.  No additional ticket, frontend, or provider
comparison is needed for the design work.

## Acceptance and verification

Provider-free request/service tests and Vue tests must cover the full matrix
below.  The sandbox must run the identical authorized orchestration/revision
path in a rollback transaction; it is not evidence of live-model quality.
Approved owner-only pilot verification remains separately labelled, bounded by
the current authorization and budget, with no live send in ordinary tests.

| Scenario | Exact input/context | Assert |
| --- | --- | --- |
| Swahili greeting | `Habari yako`; selected Offer; revenue missing | Swahili natural greeting/invitation; no revenue/budget/call question; evidence unchanged. |
| Known name | Lead name already evidence-backed | No repeated name request; Offer answer is not gated on an unknown name. |
| Information request | `Nataka kujua huduma mnazotoa` | Approved Swahili answer and at most one relevant situation/interest follow-up. |
| Multi-fact | Online teaching business; `800,000 TZS` current monthly revenue; `3,000,000 TZS` goal; suitability question | Grounded Swahili answer; current revenue and goal stored separately with evidence; no repeated business/revenue question. |
| Correction | `Samahani, mapato ni 600000 kwa mwezi, sio 800000` | Current revenue is superseded through correction lineage; goal survives; rules recompute. |
| Interested/no budget | Student, no current business/funds, interest in expertise business | No student-only exclusion; fit and readiness distinct; only ADR-approved resource behavior, otherwise truthful no-resource response. |
| No interest | `Sitaki kujenga biashara wala kupata huduma hizi` | Polite close; no qualification pressure or community invitation. |
| Ready | Configured fit/readiness met and explicit `sales_call_agreement` | Team view carries business, current revenue, goal, obstacle, evidence/unknowns/agreement and deterministic handoff controls. |
| Unknown | Relevant unsupported business question | Review Request and truthful acknowledgement; no appended financial interview. |
| Human/stop | `Naomba mtu wa timu` / `Sitaki ujumbe zaidi` | Existing handover/opt-out controls win; no qualification trap. |
| Other Offer | Product Offer with qualification disabled | Approved answer plus configured purchase/enquiry behavior; no coaching/revenue gate. |

In-app browser evidence is required on both desktop and a phone viewport:

- The six sections are discoverable in order; advanced controls are collapsed
  but keyboard reachable and validation errors remain tied to their fields.
- Owner can make a source proposal, edit suggested wording, inspect history,
  save a commercial draft, publish deliberately, and see stale-version conflict
  recovery without losing independent current edits.
- The preview shows a multi-turn Swahili and English run, remembered evidence,
  current versus desired revenue, unknowns, fit/readiness, selected next step,
  configuration/source revision, simulation/no-send state, and any provider
  cost/authorization state.
- It never displays raw internal enum/key diagnostics to a Lead, invents a
  price or resource URL, or claims an invitation/send occurred when no approved
  configuration exists.

Focused Rails/Vue checks, lint, build, cached-diff check, and immutable
release evidence follow each implementation slice.  A final supervised pilot
must cover the matrix above before readiness is claimed; mocked provider output
alone is insufficient.

## Coordinator review and first implementation boundary

Proceed with the existing owner-authorized correction; the ADR requirement is an internal design record, not a new user permission requirement. Conditional outcomes are already requested by the owner. Record representation/precedence before implementing them; do not silently omit them from final acceptance.

The first bounded slice centralizes question eligibility and suppresses greetings/unknown/refusal/human/stop interviews across reply paths, with tests preserving eligible handover and approved information replies. It must not invent universal profession, income or coaching stages. Assessment-required and conversation-useful remain different concepts. If a local path cannot render the configured question in the current language, omit the follow-up rather than copy another language; subsequent language/rendering work must make useful questions available without new unmetered calls. Do not claim adaptive selection fully implemented by simply wrapping the old ordered selector.

Prepare the six-section UI immediately after this small runtime slice, before extended low-level tuning, so the owner can inspect tangible setup improvements. Preserve the current CE design and sole price/source authority. Future contextual selection must support arbitrary business-defined information requirements and optional goal/obstacle fields.
