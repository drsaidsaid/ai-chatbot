import { ControlState, transitionConversation, maySendAiReply } from "./control-state.js";

function isHumanMessage(event) {
  return event.event === "message_created" && event.messageType === "outgoing" && event.senderType !== "agent_bot";
}

function isInboundLeadMessage(event) {
  return event.event === "message_created" && event.messageType === "incoming";
}

function controlEventFromChatwoot(event) {
  if (isInboundLeadMessage(event)) return { type: "lead_message" };
  if (isHumanMessage(event)) return { type: "human_reply" };
  if (event.event === "conversation_resolved") return { type: "resolve" };
  if (event.event === "conversation_updated" && event.assigneeId) return { type: "human_assigned" };
  return null;
}

export class ConversationService {
  constructor({ repository, chatwootApi, businessAccountId }) {
    this.repository = repository;
    this.chatwootApi = chatwootApi;
    this.businessAccountId = businessAccountId;
  }

  ingest(event, deliveryId) {
    const eventId = deliveryId ?? `${event.event}:${event.messageId ?? event.conversationId}`;
    if (!this.repository.acceptEvent({ id: eventId, event })) {
      return { duplicate: true, conversation: null };
    }

    if (!event.conversationId) throw new Error("Chatwoot event did not include a conversation ID");

    const lead = this.repository.upsertLead({
      businessAccountId: this.businessAccountId,
      externalContactId: event.contactId,
      name: event.contactName,
      phoneNumber: event.phoneNumber,
    });
    const conversation = this.repository.getOrCreateConversation({
      businessAccountId: this.businessAccountId,
      externalConversationId: event.conversationId,
      lead,
    });

    if (event.messageId) {
      this.repository.saveMessage({
        externalMessageId: event.messageId,
        conversationId: conversation.id,
        direction: event.messageType,
        actorType: event.senderType,
        content: event.content,
        occurredAt: event.occurredAt,
      });
    }

    const controlEvent = controlEventFromChatwoot(event);
    const next = controlEvent ? transitionConversation(conversation, controlEvent) : conversation;
    this.repository.saveConversation(next);
    this.repository.recordAudit({ eventId, action: controlEvent?.type ?? "webhook_recorded", conversationId: next.id });

    return { duplicate: false, conversation: next };
  }

  changeControl({ externalConversationId, type }) {
    const conversation = this.repository.getConversation({
      businessAccountId: this.businessAccountId,
      externalConversationId,
    });
    if (!conversation) throw new Error("Conversation not found");

    const next = transitionConversation(conversation, { type });
    this.repository.saveConversation(next);
    this.repository.recordAudit({ action: type, conversationId: next.id });
    return next;
  }

  async sendQueuedAiReply({ externalConversationId, content }) {
    const conversation = this.repository.getConversation({
      businessAccountId: this.businessAccountId,
      externalConversationId,
    });
    if (!conversation || !conversation.aiReplyQueued || !maySendAiReply(conversation)) {
      return { sent: false, reason: "ai_no_longer_owns_conversation" };
    }

    // Production replaces this repository read with a row lock and re-read transaction.
    const message = await this.chatwootApi.sendTextMessage({
      conversationId: externalConversationId,
      content,
    });
    this.repository.saveConversation({ ...conversation, aiReplyQueued: false });
    this.repository.recordAudit({ action: "ai_reply_sent", conversationId: conversation.id });
    return { sent: true, message };
  }

  getOperatorSummary(externalConversationId) {
    const conversation = this.repository.getConversation({
      businessAccountId: this.businessAccountId,
      externalConversationId,
    });
    return conversation
      ? {
          ...conversation,
          canAiReply: maySendAiReply(conversation),
          isHumanOwned: conversation.controlState === ControlState.HUMAN_ACTIVE,
        }
      : null;
  }
}
