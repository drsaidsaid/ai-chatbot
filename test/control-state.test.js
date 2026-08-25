import assert from "node:assert/strict";
import test from "node:test";

import { ChatwootApi, normalizeChatwootEvent, verifyChatwootWebhook } from "../src/lib/chatwoot.js";
import { ConversationService } from "../src/lib/conversation-service.js";
import { ControlState } from "../src/lib/control-state.js";
import { InMemoryLeadRepository } from "../src/lib/in-memory-repository.js";

function createService(chatwootApi = { sendTextMessage: async () => ({ id: 1 }) }) {
  return new ConversationService({
    repository: new InMemoryLeadRepository(),
    chatwootApi,
    businessAccountId: "business-1",
  });
}

function inboundMessage(id = "message-1") {
  return normalizeChatwootEvent({
    event: "message_created",
    id,
    message_type: "incoming",
    content: "I need help with my WhatsApp leads",
    conversation: {
      id: 42,
      status: "pending",
      meta: { sender: { id: 9, name: "Asha", phone_number: "+255700000001" } },
    },
    inbox: { id: 3 },
  });
}

test("accepts one inbound event and ignores an identical delivery", () => {
  const service = createService();
  const first = service.ingest(inboundMessage(), "delivery-1");
  const repeated = service.ingest(inboundMessage(), "delivery-1");

  assert.equal(first.duplicate, false);
  assert.equal(first.conversation.aiReplyQueued, true);
  assert.equal(repeated.duplicate, true);
});

test("a late AI job is blocked after a human reply", async () => {
  let sends = 0;
  const service = createService({
    sendTextMessage: async () => {
      sends += 1;
      return { id: 88 };
    },
  });
  service.ingest(inboundMessage(), "delivery-1");
  service.ingest(
    normalizeChatwootEvent({
      event: "message_created",
      id: 2,
      message_type: "outgoing",
      content: "I will take this one.",
      sender: { type: "user", name: "Operator" },
      conversation: { id: 42, status: "open" },
    }),
    "delivery-2",
  );

  const result = await service.sendQueuedAiReply({ externalConversationId: "42", content: "Test reply" });
  assert.deepEqual(result, { sent: false, reason: "ai_no_longer_owns_conversation" });
  assert.equal(sends, 0);
  assert.equal(service.getOperatorSummary("42").controlState, ControlState.HUMAN_ACTIVE);
});

test("manual resume does not send a reply until a later lead message", () => {
  const service = createService();
  service.ingest(inboundMessage(), "delivery-1");
  service.changeControl({ externalConversationId: "42", type: "manual_pause" });
  const resumed = service.changeControl({ externalConversationId: "42", type: "manual_resume" });

  assert.equal(resumed.controlState, ControlState.AI_ACTIVE);
  assert.equal(resumed.aiReplyQueued, false);
});

test("a returning lead begins a new AI lifecycle after resolution", () => {
  const service = createService();
  service.ingest(inboundMessage(), "delivery-1");
  service.changeControl({ externalConversationId: "42", type: "resolve" });
  service.ingest(inboundMessage("message-2"), "delivery-2");

  const conversation = service.getOperatorSummary("42");
  assert.equal(conversation.controlState, ControlState.AI_ACTIVE);
  assert.equal(conversation.aiReplyQueued, true);
});

test("verifies the Chatwoot timestamp.body HMAC contract", () => {
  const rawBody = '{"event":"message_created"}';
  const timestamp = "1735689600";
  const signature = "sha256=086c7f4fd1ff8014d63031c70c0b4111f472886fa3c5d5e90bcee86fa3f4c3c7";
  assert.equal(
    verifyChatwootWebhook({
      secret: "test-secret",
      rawBody,
      timestamp,
      signature,
      now: 1735689600 * 1000,
    }),
    true,
  );
});

test("Chatwoot API posts an outgoing message through the account conversation endpoint", async () => {
  let request;
  const api = new ChatwootApi({
    baseUrl: "https://chat.example.test/",
    accountId: "1",
    apiToken: "token",
    fetchImpl: async (url, options) => {
      request = { url, options };
      return new Response(JSON.stringify({ id: 3 }), { status: 200 });
    },
  });

  await api.sendTextMessage({ conversationId: "42", content: "Hello" });
  assert.equal(request.url, "https://chat.example.test/api/v1/accounts/1/conversations/42/messages");
  assert.equal(request.options.headers.api_access_token, "token");
  assert.deepEqual(JSON.parse(request.options.body), { content: "Hello", message_type: "outgoing", private: false });
});
