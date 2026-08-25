# Direct Meta WhatsApp Cloud API Integration

**Issue:** GitHub #3  
**Date:** 2026-08-25  
**Scope:** The owned AI Lead Employee inbox connects directly to Meta's WhatsApp
Cloud API. This note uses only first-party Meta documentation.

## Decision summary

Build one owned WhatsApp adapter around Meta's Cloud API. It must verify and
persist webhooks before processing them, deduplicate inbound and status events,
and treat delivery status as asynchronous. The app must use a permanent system
user token in production, not the temporary token shown in Meta's quickstart.

## Prerequisites and rollout

1. Create a Meta developer app using the **Connect with customers through
   WhatsApp** use case, select or create a business portfolio, and connect a
   WhatsApp Business Account (WABA). Development requires a Facebook or managed
   Meta account, developer registration, and a WhatsApp-enabled test device.
   [Meta quickstart](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started)
2. Use Meta's automatically created and registered **test business phone
   number** to prove the complete inbound and outbound path first. Keep its
   `phone_number_id` and the WABA ID. Do not put customer traffic on it.
   [Meta quickstart](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started)
3. For production, add and register a business number. It must be owned by the
   business, include country and area code, and receive SMS or voice calls for
   verification; it must be `CONNECTED` to send and receive through the API.
   Meta says a number already used in WhatsApp cannot be registered unless it is
   first deleted from WhatsApp. Confirm this early with every client because it
   can affect migration planning.
   [Meta business phone numbers](https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/phone-numbers)
4. Create a system user, grant it the app and WABA assets, and generate a
   permanent token with `business_management`, `whatsapp_business_messaging`,
   and `whatsapp_business_management`. Meta explicitly says the temporary
   quickstart token expires quickly and is not suitable for development or
   production use.
   [Meta quickstart](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started)
5. Promote the Meta app to Live as part of production readiness. Meta notes that
   some webhooks are not delivered while an app is in Development mode.
   [Meta webhooks overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview)

### App Review and permission boundary

Meta says App Review is not required when only people with an app role use the
app. Do not assume that exception applies beyond internal testing: once we
onboard businesses that are not app-role users, the app must pass App Review for
the permissions it requests.
For a partner providing WhatsApp services to customer businesses, Meta's webhook
documentation specifically requires approved Advanced Access before customers
can grant `whatsapp_business_messaging` and `whatsapp_business_management` during
onboarding. Advanced Access also requires business verification. Treat this as a
launch blocker before the first external client onboarding, not before internal
testing. [Meta App Review](https://developers.facebook.com/docs/app-review)
[Meta permissions](https://developers.facebook.com/docs/permissions)
[Meta webhooks overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview)

## Webhook contract

Use one publicly reachable HTTPS callback. Meta requires a valid TLS/SSL
certificate and does not support self-signed certificates.
[Meta webhook endpoint setup](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)

### Verification: `GET /webhooks/meta/whatsapp`

When the callback URL or verify token is saved in Meta's dashboard, Meta calls:

```text
GET <callback>?hub.mode=subscribe&hub.challenge=<challenge>&hub.verify_token=<token>
```

Compare `hub.verify_token` with our stored token. If it matches, return HTTP 200
with the exact `hub.challenge`; otherwise return a non-200 response. Meta will
not send events until this succeeds.
[Meta webhook endpoint setup](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)

### Events: `POST /webhooks/meta/whatsapp`

Verify `X-Hub-Signature-256` before parsing or queuing the payload. Compute
HMAC-SHA256 from the **raw** POST body using the Meta app secret and compare the
result to the header value after `sha256=` using a timing-safe comparison. A
valid event receives HTTP 200; an invalid event receives a non-200 response.
[Meta webhook endpoint setup](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)

Subscribe to the `messages` field for V1. It contains both inbound customer
messages and statuses for messages sent by the business. Also subscribe to
template status/quality and phone-number quality fields before production so the
team can see a template or delivery-capability problem promptly.
[Meta webhooks overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview)

### Inbound payload essentials

For every `entry[].changes[]` whose `field` is `messages`, extract:

- `value.metadata.phone_number_id`: route the event to the owned inbox account.
- `value.contacts[].wa_id` and `profile.name`: identify and label the contact.
- Each `value.messages[]` item: `id`, `from`, `timestamp`, `type`, and its
  type-specific content such as `text.body`.
- Each `value.statuses[]` item: outgoing message ID, lifecycle status, timestamp,
  recipient, and any error data, to update the owned outbound-message record.

Meta may batch up to 1,000 updates in a POST, but batching is not guaranteed, so
iterate all entries, changes, and message/status arrays. Webhook bodies can be
up to 3 MB. [Meta webhook endpoint setup](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)
[Meta webhooks overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview)

## Idempotency, retries, and ordering

- A non-200 webhook response, or a failed delivery, is retried immediately and
  then at decreasing frequency for up to seven days. Meta warns that this can
  create duplicate notifications. Persist each valid raw payload and use unique
  keys before enqueueing work: inbound `messages[].id`; outgoing status as
  `statuses[].id + status + timestamp`; and a raw-event digest for other event
  types. [Meta webhook endpoint setup](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/create-webhook-endpoint)
- Commit the deduplication record and the durable processing job in one database
  transaction, then return 200. The actual AI reply may run asynchronously. This
  is our design response to Meta's at-least-once delivery behaviour.
- A successful send response means Meta accepted the request, **not** that the
  lead received it. Store the returned WhatsApp message ID and use `messages`
  status webhooks as the delivery source of truth.
  [Meta service messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages)
- Message delivery order is not guaranteed to match send-request order. For a
  sequence where order matters, wait for the prior `delivered` status before
  sending the next message. [Meta service messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages)
- Do not blindly replay a timed-out outbound request. First reconcile the local
  outbound job and any received status webhook, because the request may have
  reached Meta even when our client did not receive a response. This is an
  implementation inference from Meta's asynchronous acceptance and webhook
  delivery model.

## Outbound messages

Send through:

```text
POST https://graph.facebook.com/<META_GRAPH_API_VERSION>/<META_WHATSAPP_PHONE_NUMBER_ID>/messages
Authorization: Bearer <META_WHATSAPP_ACCESS_TOKEN>
Content-Type: application/json
```

The request requires `messaging_product: "whatsapp"`, recipient `to`, a message
`type`, and the matching type-specific object. The API reference requires a
Bearer access token and identifies the endpoint as `/{version}/{phone-number-id}/messages`.
[Meta Messages API reference](https://developers.facebook.com/documentation/business-messaging/whatsapp/reference/whatsapp-business-phone-number/message-api)

For the lead flow, begin with text and optionally interactive reply buttons for
budget bands. The agent must send a free-form service reply only while the
customer-service window is open and the lead has opted in.

### Templates and the 24-hour customer-service window

The 24-hour customer-service window begins or resets when a user messages or
calls the business. During the window the agent may send free-form service
messages. Once it closes, it may send only pre-approved template messages; the
lead must have opted in to receive business messages. Therefore, follow-up and
re-engagement flows must select an approved template rather than attempting an
ordinary AI-generated text reply.
[Meta service messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages)

For V1, record `last_customer_message_at` on every inbound message and calculate
window eligibility before creating any outbound job. Keep approved template name,
language, and parameters in configuration, never hard-coded in prompts.

## Recommended environment variables

```dotenv
# Meta app and Graph API routing
META_APP_ID=
META_APP_SECRET=                 # Secret: validates X-Hub-Signature-256
META_GRAPH_API_VERSION=          # Pin a supported version; upgrade deliberately

# WhatsApp Business account and sender identity
META_WHATSAPP_BUSINESS_ACCOUNT_ID=
META_WHATSAPP_PHONE_NUMBER_ID=
META_WHATSAPP_ACCESS_TOKEN=      # Secret: permanent system-user token

# Inbound webhook configuration
META_WEBHOOK_VERIFY_TOKEN=       # Secret: high-entropy, server-generated
META_WEBHOOK_CALLBACK_URL=        # Public HTTPS URL registered in Meta dashboard

# Approved outbound templates used after the 24-hour window
META_WHATSAPP_FOLLOW_UP_TEMPLATE_NAME=
META_WHATSAPP_FOLLOW_UP_TEMPLATE_LANGUAGE=
```

Keep `META_APP_SECRET`, `META_WHATSAPP_ACCESS_TOKEN`, and
`META_WEBHOOK_VERIFY_TOKEN` only in the deployment secret store. Never expose
them to the browser, commit them, or include them in application logs. At rest,
the system-user token should be encrypted if it is ever stored per client rather
than supplied solely by deployment configuration.

## V1 implementation checklist

1. Validate the test number, webhook GET verification, signed POST acceptance,
   inbound text storage, and outbound text reply end to end.
2. Add transactional inbound/status deduplication and durable background jobs
   before enabling the AI responder.
3. Track sent, delivered, read, and failed statuses in the owned conversation.
4. Enforce the 24-hour check and template-only fallback before every send.
5. Register the production phone number, move the app to Live, and verify the
   webhook and permanent-token path again before real lead traffic.
6. Before onboarding a client business, complete the required App Review,
   Advanced Access, and business-verification path identified above.
