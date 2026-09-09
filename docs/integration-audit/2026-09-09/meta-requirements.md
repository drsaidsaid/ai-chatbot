# Current Meta requirements and audit implications

Verified from official public pages on 9 September 2026. Documentation access did not involve a Meta login, account connection, test number, or message. Some developer pages were rate-limited through the web reader and were read in the browser instead. Page update dates below are the dates displayed, not a claim that a rule began on that day. No message price or Tanzania-specific legal conclusion is asserted here.

## Permission and customer control

Businesses need the recipient’s number and permission for subsequent communications, must respect stop requests, and must provide a clear human escalation route when using automation. Outside the customer service window, approved templates are required for initiating the relevant messages. This makes opt-out handling, human access, and template eligibility live-path requirements. [WhatsApp Business Messaging Policy](https://business.whatsapp.com/policy)

The opt-in guide, updated 16 June 2026, explains that permission may be general rather than WhatsApp-specific following the November 2024 policy update, subject to applicable requirements. The business and communications must be clear. For OP, explicit channel/purpose wording and stored evidence are a stronger product choice; they are not a universal Meta mandate for a separate checkbox. A stored boolean should be traced to the actual capture wording and action before treating it as permission. [Getting opt-in](https://developers.facebook.com/documentation/business-messaging/whatsapp/getting-opt-in/)

## Service window and message outcomes

The service-messaging guide, updated 21 May 2026, describes the 24-hour window renewed by customer messages/calls and the need for approved templates outside it. The API’s acceptance response is not confirmation of recipient delivery. Message ordering is not guaranteed merely because requests were made in sequence. OP should base eligibility on trustworthy customer event time and use status events for outcomes; do not count an ad click, consent checkbox, or webhook processing time as a new inbound message. [Service messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages)

Status reference, updated 21 May 2026: sent, delivered, read, and failed describe distinct events. Read implies delivery, so a delivered event can be omitted. Preserve event time and avoid regressing read to sent. biz_opaque_callback_data can correlate a status when supplied on sending. The conversation object is generally omitted in v24+ except the documented free-entry case, so its ID must not become OP’s canonical CRM conversation key. [Status webhook reference](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/reference/messages/status/)

## Webhook authentication, completeness, and recovery

The endpoint guide, updated 17 June 2026, requires a valid HTTPS endpoint, a separate GET verification challenge, and POST authenticity checked using the raw body and app-secret HMAC-SHA256 signature. It documents batching up to 1,000 updates, retries for up to seven days, and no general API to retrieve historical webhook data. Accordingly, the audit recommends durable authenticated receipts before acknowledgement, full array processing, idempotency, and an owned replay ledger. [Create a webhook endpoint](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint/)

The webhook overview, updated 26 June 2026, describes payloads up to 3 MB and retry/duplicate behavior after unsuccessful delivery. It distinguishes direct-developer setup from partners that need Advanced Access/App Review before onboarding customers; do not assume the latter requirement applies identically to an internal OP setup. Live mode and field subscriptions matter. Verify messages, template status/quality, phone/account status, and relevant user_preferences events for the chosen integration. [Webhook overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview/)

These requirements support the proposed event ledger, but a 30-day raw-event retention period, dead-letter design, and internal monitoring thresholds are audit recommendations, not Meta-prescribed values.

## Click-to-WhatsApp attribution and identity

The text-message reference, updated 21 May 2026, documents referral fields such as source_id, source_url, source_type, headline/body, and ctwa_clid on qualifying inbound ad-originated messages. ctwa_clid can be absent for WhatsApp Status ad placements. The same reference states that WhatsApp user ID and phone number need not match. Preserve supplied referral fields as dated observed evidence, allow missing fields, and do not invent an ad/campaign mapping. An ad click without an inbound event does not give the inbox a verified customer identity. [Text-message webhook reference](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/reference/messages/text/)

The current CE incoming service retains the referral object on message content attributes. That is a useful starting point; first/last-touch projections, person links, and multi-offer attribution still need an explicit model. Website UTM data and Meta referral data have different provenance and should remain distinguishable.

## AI-provider use

The current Business Solution Terms distinguish a business’s ancillary AI-assisted service from offering general-purpose AI as the primary WhatsApp functionality, with regional provisions. They also restrict use of Business Solution Data for broader model training/improvement and address permitted AI-provider processing. The appropriate OP scope is a bounded business assistant. Verify the selected provider’s contractual processing/retention terms and configuration; an adapter’s ZDR request alone is not proof of compliance. [WhatsApp Business Solution Terms](https://www.whatsapp.com/legal/business-solution-terms)

## Still requires separately authorized operational proof

Confirm the actual app/WABA/phone mapping, selected Graph version and support lifecycle, token permissions/rotation, webhook subscription/signatures, business verification/display-name requirements where applicable, template approval/category/locale/quality, billing and limits, and chosen provider behavior. Test the real manual or embedded setup path and customer response windows using approved test assets. This audit did not inspect these private assets, change them, or certify deliverability.
