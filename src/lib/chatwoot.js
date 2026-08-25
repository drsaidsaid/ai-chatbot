import { createHmac, timingSafeEqual } from "node:crypto";

const MAX_SIGNATURE_AGE_SECONDS = 5 * 60;

function safeEqual(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

export function verifyChatwootWebhook({ secret, rawBody, timestamp, signature, now = Date.now() }) {
  if (!secret || !timestamp || !signature) return false;

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) return false;
  if (Math.abs(now / 1000 - timestampSeconds) > MAX_SIGNATURE_AGE_SECONDS) return false;

  const expected = `sha256=${createHmac("sha256", secret)
    .update(`${timestamp}.${rawBody}`)
    .digest("hex")}`;

  return safeEqual(expected, signature);
}

export function normalizeChatwootEvent(payload) {
  const event = payload.event;
  const conversation = payload.conversation ?? {};
  const sender = payload.sender ?? {};

  return {
    event,
    messageId: payload.id ? String(payload.id) : null,
    conversationId: conversation.id ? String(conversation.id) : null,
    inboxId: payload.inbox?.id ? String(payload.inbox.id) : null,
    contactId: conversation.meta?.sender?.id ? String(conversation.meta.sender.id) : null,
    contactName: conversation.meta?.sender?.name ?? sender.name ?? null,
    phoneNumber: conversation.meta?.sender?.phone_number ?? sender.phone_number ?? null,
    content: payload.content ?? "",
    messageType: payload.message_type ?? null,
    senderType: sender.type ?? null,
    assigneeId: conversation.assignee_id ? String(conversation.assignee_id) : null,
    assigneeAgentBotId: conversation.assignee_agent_bot_id
      ? String(conversation.assignee_agent_bot_id)
      : null,
    chatwootStatus: conversation.status ?? null,
    occurredAt: payload.created_at ? new Date(payload.created_at) : new Date(),
  };
}

export class ChatwootApi {
  constructor({ baseUrl, accountId, apiToken, fetchImpl = fetch }) {
    this.baseUrl = baseUrl?.replace(/\/$/, "");
    this.accountId = accountId;
    this.apiToken = apiToken;
    this.fetch = fetchImpl;
  }

  async sendTextMessage({ conversationId, content }) {
    const response = await this.fetch(
      `${this.baseUrl}/api/v1/accounts/${this.accountId}/conversations/${conversationId}/messages`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          api_access_token: this.apiToken,
        },
        body: JSON.stringify({ content, message_type: "outgoing", private: false }),
      },
    );

    if (!response.ok) {
      throw new Error(`Chatwoot message request failed with ${response.status}`);
    }

    return response.json();
  }
}
