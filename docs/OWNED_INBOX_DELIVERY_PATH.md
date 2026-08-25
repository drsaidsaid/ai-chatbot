# Owned Inbox Delivery Path

This is the required route for agents working on the owned AI Lead Employee
product. It follows the Ask Matt multi-session flow.

1. **Re-baseline the source:** make the Community Edition source the owned
   product foundation, retain the MIT notice, exclude enterprise content, and
   preserve a reviewable upstream reference.
   Done when the application can boot from our repository without a Chatwoot
   service account, API token, or webhook secret.

2. **Own identity and tenancy:** brand the application, establish our user
   authentication, and scope every owned record by Business Account.
   Done when a Human Operator signs into our product and cannot cross Business
   Account boundaries.

3. **Connect Meta directly:** receive and verify Meta WhatsApp webhooks and send
   outbound WhatsApp messages from our backend.
   Done when a Meta test number completes a durable inbound and outbound message
   round trip.

4. **Protect conversation control:** persist Control State, deduplicate provider
   events, and block stale AI jobs after a Human Operator takes ownership.
   Done when duplicate delivery, handoff, pause, manual resume, and late-job
   scenarios pass against the owned inbox.

5. **Add the AI Lead Employee workflow:** implement approved knowledge,
   one-question qualification, handoff, alerting, booking, follow-up, and review
   requests as the tickets specify.
   Done when each ticket's acceptance criteria, tests, and review pass before the
   next ticket begins.

Do not create a separate Chatwoot-service integration. Meta credentials are the
only messaging-provider credentials required by this architecture.
