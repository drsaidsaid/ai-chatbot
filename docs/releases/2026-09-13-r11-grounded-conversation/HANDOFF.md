# Handoff

Review source commit `dad021eb9b2cd50a894f9663a39d26696279334d`
against integrated baseline `fbee83c96afa58ab1610a0f480b34eb04b1e5ef8`.

The main runtime changes are in:

- `AiLeadEmployee::Orchestration::IntentProcessor`
- `AiLeadEmployee::KnowledgeAnswerService`
- `AiLeadEmployee::ConversationIntentClassifier`
- `AiLeadEmployee::CommercialClaimValidator`
- `AiLeadEmployee::PublicConversationContext`
- `AiLeadEmployee::OfferProgressionService`
- `AiLeadEmployee::OfferAnswerContext`
- `Whatsapp::OutboundEligibility`

Reviewer attention should center on source-current checks across the provider
round trip, Review/outbox transaction ordering, Offer authority at delivery,
commercial-claim polarity, and the separation between relevant unknowns,
unrelated questions and human-help requests.

The earlier 10 September evidence directory remains historical and unchanged.
Its exact candidate is recoverable from
`codex/r11-emergency-conversation-repair-pre-fbee83c`. The active candidate
removes its superseded fixed-interview tests and uses the 12 September amendment.

No database migration is required. `human_requested` appends enum value 10 and
does not renumber persisted reasons. Rollback is the source commit revert; no
data rewrite is needed. Approval revision arrays written after deployment remain
valid legacy metadata if the source commit is reverted.
