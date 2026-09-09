---
status: accepted
---

# Use the existing Community Edition WhatsApp channel as the canonical Meta path

AI Lead Employee will receive Meta WhatsApp events through the owned Community Edition WhatsApp channel webhook, persist them through the existing Conversation and Message pipeline, and send replies through the existing WhatsApp outbound sender. The duplicate custom `/webhooks/meta/whatsapp` design is not the production path because it bypasses useful Community Edition behavior such as channel lookup, coexistence echoes, message hooks, attachments, delivery status handling, and the configured Channel Greeting.

## Consequences

- The implementation must retire or quarantine the parallel custom Meta controller and processor before later AI behavior is trusted.
- The canonical round trip is Meta to `Webhooks::WhatsappController`, `Webhooks::WhatsappEventsJob`, `Whatsapp::IncomingMessageWhatsappCloudService`, persisted Conversation and Message records, durable AI Orchestration, and the existing WhatsApp sender.
- A Channel Greeting remains intentional. The Lead's first Inbound Message, the greeting, and the AI Employee's answer must all stay visible in the Conversation.
- WhatsApp Business app coexistence echoes are human activity for Control State and must stop pending AI work.
