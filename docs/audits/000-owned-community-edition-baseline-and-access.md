# Ticket 000 Owned Community Edition Baseline, Access, and Route Audit

## Baseline Verification

- The worktree starts from `codex/reconcile-v1-baseline` at `e469a4e`.
- `VERSION_CW` pins Chatwoot Community Edition `4.17.0`.
- `LICENSE` retains the Community Edition MIT Expat notice.
- The repository has no `enterprise/` directory at the owned product root.
- `upstream-chatwoot` is present as the read-only upstream reference remote.
- `config/installation_config.yml` brands the runtime as `AI Lead Employee` and disables public account creation through `ENABLE_ACCOUNT_SIGNUP=false` and `CREATE_NEW_ACCOUNT_FROM_DASHBOARD=false`.
- `Procfile.dev`, `config/cable.yml`, `config/initializers/sidekiq.rb`, and `config/environments/development.rb` keep the Rails, Vue, Redis, and worker processes inside this owned application boundary.

## Access And Tenancy Verification

- Owned access retains the Community Edition `User`, `Account`, `AccountUser`, Devise token auth, password recovery, invitation, and role foundation.
- `Api::V1::Accounts::BaseController` resolves `Current.account` server-side via `EnsureCurrentAccountHelper`; the signed-in user must have an `account_users` membership for the requested account.
- Lead qualification reads and evidence writes now authorize the actual account-scoped `LeadQualification` record, and `LeadQualificationPolicy::Scope` only resolves records for the current Business Account.
- Request coverage verifies sign-in, password recovery, invite-only team member creation, rejected non-member access, and background job queries scoped to the selected Business Account.
- Additional policy and request coverage verifies admins and team members cannot read or write Lead Qualification data across Business Account boundaries, even when the same user belongs to both accounts.

## V1 Navigation Verification

- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` builds its sidebar through `buildAILeadEmployeeMenuItems`.
- `buildAILeadEmployeeMenuItems` exposes only Inbox, Hot Leads, Leads, Reviews, Knowledge, Bookings, and Settings at the top level.
- Contacts, Reports, Campaigns, Help Center, Integrations, and other unrelated Community Edition surfaces remain in the source for later decisions but are hidden from V1 top-level navigation.
- Owned workflow routes are account-scoped under `/app/accounts/:accountId/hot-leads`, `/leads`, `/reviews`, `/knowledge`, and `/bookings`.

## Duplicate Meta And Inline AI Audit

The duplicate custom Meta path is donor code and is not production:

- `config/routes.rb` still routes `GET /webhooks/meta/whatsapp` and `POST /webhooks/meta/whatsapp` to `Webhooks::Meta::WhatsappController` so callers receive a controlled retired-path response.
- `app/controllers/webhooks/meta/whatsapp_controller.rb` now returns `410 Gone` and does not parse, verify, persist, enqueue, or call AI behavior.
- `app/services/meta/whatsapp/inbound_webhook_processor.rb` is donor-only code. Its previous `send_ai_employee_reply!` branch called `AiLeadEmployee::WhatsappAutoReplyService` inline after message persistence.
- `app/services/ai_lead_employee/whatsapp_auto_reply_service.rb` is donor-only inline AI behavior until ticket 002 replaces it with durable AI Orchestration.
- `app/services/meta/whatsapp/outbound_message_sender.rb` and `app/services/meta/whatsapp/text_message_client.rb` are donor-only sender/client code until outbound behavior is folded into the existing `Whatsapp::SendOnWhatsappService` path.
- Exact duplicate Meta and inline AI call sites found in this audit:
  - `config/routes.rb`: `GET /webhooks/meta/whatsapp` and `POST /webhooks/meta/whatsapp`.
  - `app/controllers/webhooks/meta/whatsapp_controller.rb`: retired custom controller actions.
  - `app/services/meta/whatsapp/inbound_webhook_processor.rb`: donor custom inbound processor and inline `AiLeadEmployee::WhatsappAutoReplyService` call.
  - `app/services/meta/whatsapp/outbound_message_sender.rb`: donor custom outbound sender.
  - `app/services/meta/whatsapp/text_message_client.rb`: donor custom Meta text client.
  - `app/services/ai_lead_employee/whatsapp_auto_reply_service.rb`: donor inline AI reply workflow and custom sender call.
  - `app/services/ai_lead_employee/follow_up_delivery_service.rb`: donor follow-up delivery call to `Meta::Whatsapp::OutboundMessageSender`.
  - `app/services/ai_lead_employee/human_review_request_service.rb`: donor alert call to `Meta::Whatsapp::TextMessageClient`.
  - `app/services/ai_lead_employee/booking_service.rb`: donor booking confirmation call to `Meta::Whatsapp::TextMessageClient`.
  - `app/services/ai_lead_employee/highly_qualified_handoff_service.rb`: donor handoff alert call to `Meta::Whatsapp::TextMessageClient`.
  - `spec/requests/webhooks/meta/whatsapp_controller_spec.rb`: quarantine coverage for the retired custom route.
  - `spec/services/ai_lead_employee/whatsapp_auto_reply_service_spec.rb` and `spec/services/meta/whatsapp/outbound_message_sender_spec.rb`: donor behavior specs to replace or delete as later tickets move behavior to the canonical path.

Production WhatsApp traffic must use `Webhooks::WhatsappController`, `Webhooks::WhatsappEventsJob`, `Whatsapp::IncomingMessageWhatsappCloudService`, persisted `Conversation` and `Message` records, and `Whatsapp::SendOnWhatsappService`.
