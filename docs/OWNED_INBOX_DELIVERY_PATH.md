# Owned Inbox Delivery Path

This is the required route for agents working on the owned AI Lead Employee
product. It follows the Ask Matt multi-session flow.

1. **Re-baseline the source:** keep the Community Edition source as the owned
   product foundation, retain the MIT notice, exclude enterprise content, and
   preserve a reviewable upstream reference.
   Done when the application boots from our repository without a Chatwoot
   service account, API token, webhook secret, or separate Chatwoot database.

2. **Own identity and tenancy:** retain and rebrand the Community Edition User,
   Account, AccountUser, Devise, invitation, and tenancy foundations.
   Done when a Human Operator signs into our product and every request, job, and
   query resolves Business Account scope server-side.

3. **Restore the canonical WhatsApp path:** route Meta events through the
   existing Community Edition WhatsApp webhook, event job, channel service,
   Conversation and Message records, and existing outbound sender. Retire or
   quarantine the duplicate custom Meta webhook design.
   Done when a Meta test number completes the durable path from verified inbound
   event to visible persisted Conversation to outbound WhatsApp delivery.

4. **Coordinate the Channel Greeting:** keep the configured greeting intentional
   and visible while ensuring AI Orchestration runs on the Lead's actual first
   message and suppresses duplicate salutations.
   Done when first-message scenarios show the Lead message, greeting, and AI
   answer in the correct order without hiding or duplicating content.

5. **Protect conversation control:** persist Control State, deduplicate provider
   events, treat WhatsApp coexistence echoes as human activity, and block stale
   AI jobs after a Human Operator takes ownership.
   Done when duplicate delivery, assignment, human reply, coexistence echo,
   handoff, pause, resolution, manual resume, and late-job scenarios pass
   against the owned inbox.

6. **Add secure grounded AI:** configure an encrypted OpenAI-compatible provider
   adapter with OpenRouter initially, approved relevant Knowledge Items, verified
   Source References, failure classification, and Review Request behavior.
   Done when the AI Employee can answer from approved sources and refuses or
   requests review without fabricated fallback on missing, conflicting,
   unverified, sensitive, angry, or provider-failed cases.

7. **Recover later V1 workflows selectively:** implement qualification,
   handoff, alerts, booking, follow-up, dashboards, and launch proof only after
   the canonical round trip and durable AI boundary are demonstrably correct.
   Done when each ticket's acceptance criteria, tests, and review pass before the
   next dependent ticket begins.

Do not create a separate Chatwoot-service integration. Meta credentials are the
only messaging-provider credentials required for WhatsApp. AI provider
credentials are separate encrypted server-side model credentials.
