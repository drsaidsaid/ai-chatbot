---
status: accepted
---

# Offer-scoped qualification with typed evidence

The approved V1 glossary defines Qualification for one Offer, but the accepted
R09 starting runtime stores one account/contact evaluation and account-wide
questions. Editing a prompt does not change the fixed extractor's meaning.
R09 activates the retained `ai_lead_employee_offers` table within owned CE
Rails/Vue and implements the per-Offer path without a campaign router or workflow
builder. The coordinator confirmed this bounded decision on 2026-09-11.

Each Offer owns typed fields/questions, budget currency/ranges, bounded rules,
score thresholds and a monotonically increasing configuration revision. The
field key, answer type, meaning and any currency/period are independent of prompt
wording and order. Once used by evidence, a semantic change creates a new field
key; old definitions remain available for historical decisions. Revenue,
inquiry volume and purchase budget never share one field merely because their
question wording was changed. Custom typed answers require a verified preceding
question in the same Conversation. Disabled or intentionally absent questions
must not resurrect defaults.

Store current Qualification by `(account_id, contact_id, offer_id)`, retaining
immutable decision and configuration snapshots. Conversation records its current
Offer selection. A sole enabled Offer can be selected automatically; multiple
enabled Offers require explicit selection/clarification. An unavailable Offer
does not silently fall back to a different one. Selection is account-scoped and
authorized under current membership/assignment. Shared name/contact identity
does not make buying facts reusable across Offers. Offer-specific evidence keeps
its field identity, polarity, typed value and message/human provenance, including
superseded corrections. ADR 0010's restrictions on combined evaluations remain.

Use exact major-unit decimal strings with currency labels at the settings API
and UI, and integer minor units in storage. V1 configuration supports TZS, USD,
KES, EUR and GBP, each with two fractional digits; other currencies and excess
precision are rejected explicitly rather than assuming a universal exponent.
Reject mixed/unknown currencies for
sufficiency comparisons rather than assuming an exchange rate. Under the PRD,
`I need more leads now. I am the owner of the agency and can spend $2500`
contains positive purchase budget-capacity evidence. It does not prove committed
funds or payment. Preserve the original Highly Qualified regression input and
expectation. Explicit purchase capacity can meet an Offer's sufficient-budget
rule; salary/revenue, unrelated spending, negation, conditional funding and
unknown currency cannot establish it on their own.

Rules use a bounded, validated operator set over typed fields: presence/polarity,
equality/choice membership, and numeric/money comparisons. Hard exclusions
override score; unknown and negative evidence earn no positive score simply by
existing. Offer requirements can tighten qualification; numerical scores cannot
bypass supported pain, urgency, sufficient purchase budget and authority, or
the PRD's name/WhatsApp handoff gate. No rule executes arbitrary code and no new
unmetered model extraction path is introduced. All provider work retains R10's
metered client and final authority/allowance fences.

Configuration saves are atomic and reject stale revisions. Editing an Offer
invalidates its current evaluations and queued qualification-dependent work,
not original observations or another Offer's results. Readers show staleness;
reevaluation uses current compatible evidence and rules. Final authorization
rechecks Offer identity/revision alongside provider, consent and Conversation
control checks. Selection/configuration changes never grant consent.

Evaluation and configuration edits must serialize on the Offer row. Evaluation
acquires Conversation, then Offer, then Contact, then its Qualification rows;
reload the Offer configuration under `FOR NO KEY UPDATE` before extracting or
evaluating evidence and retain that lock through the decision write. The
configuration writer locks Offer before saving the new revision and invalidating
its evaluations; it never acquires Conversation/Contact while holding Offer.
If evaluation wins, the later edit marks its result stale; if the edit wins,
evaluation must see the new revision. No evaluation of revision N may overwrite
an N+1 invalidation with `stale_at: nil`. The Offer lock permits foreign-key key
share checks; this does not claim to repair unrelated legacy caller lock orders.

Offer selection uses a mutation-specific policy, independent of bot-readable
Conversation access. Require a real User with fresh current membership and either
administrator status or current Conversation assignment, rechecked without the
request query cache under the Conversation lock. AgentBot access to read a
Conversation grants no authority to change its Offer selection.

The Offer's validated JSON configuration is the atomic aggregate for ordered
question definitions, typed budget ranges, rules and score thresholds. Immutable
`offer_configuration_revisions` preserve complete snapshots. Existing account-wide
question and budget tables remain legacy inputs rather than a second active
per-Offer configuration store. Nullable Offer references on evidence/evaluations
preserve old records without a fabricated backfill. This physical representation
replaces the technical design's separate draft per-Offer configuration tables.

Migration preserves unscoped account-wide history and provenance. Do not attach
old results or buying evidence to an arbitrary existing Offer, even if only one
is currently enabled. Legacy configuration may be copied into a clearly labeled
Offer through an explicit migration/administrator selection, but historical
observations remain unscoped until a supported source establishes their Offer.
Never duplicate a legacy budget into all Offers. Keep legacy decision references
and avoid deleting broad CE source. Rollout must mark legacy/stale results
honestly rather than displaying them as an Offer's current evaluation.

This adds explicit field/evidence and configuration lifecycle handling, but
prevents prompt edits from silently rewriting facts and prevents one Offer's
qualification from contaminating another. The first acceptance seam saves two
Offers through HTTP and exercises incoming-message orchestration, source-linked
evaluations, exact currency round-trip, non-repeating questions and revision
invalidation. R09's preparation document records the remaining test matrix and
shared-file coordination requirements.

Evidence now has a nonnull stable `field_key`; the existing integer `signal` stays
for built-in compatibility and is nullable only for custom fields. Migration
maps existing integer signals to their known keys without changing record IDs,
values, sources or Offer scope. New Offer observations retain the field definition
used to interpret them. Configuration updates compare used definitions, including
archived keys, before accepting a semantic change; new keys represent new meanings.
