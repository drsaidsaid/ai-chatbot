import { createAiConversation } from "./control-state.js";

export class InMemoryLeadRepository {
  constructor() {
    this.events = new Map();
    this.leads = new Map();
    this.conversations = new Map();
    this.messages = new Map();
    this.auditEvents = [];
  }

  acceptEvent(event) {
    if (this.events.has(event.id)) return false;
    this.events.set(event.id, event);
    return true;
  }

  upsertLead({ businessAccountId, externalContactId, name, phoneNumber }) {
    const key = `${businessAccountId}:${externalContactId ?? phoneNumber}`;
    const existing = this.leads.get(key);
    const lead = {
      id: existing?.id ?? `lead-${this.leads.size + 1}`,
      businessAccountId,
      externalContactId,
      name: name ?? existing?.name ?? null,
      phoneNumber: phoneNumber ?? existing?.phoneNumber ?? null,
    };
    this.leads.set(key, lead);
    return lead;
  }

  getOrCreateConversation({ businessAccountId, externalConversationId, lead }) {
    const key = `${businessAccountId}:${externalConversationId}`;
    const existing = this.conversations.get(key);
    if (existing) return existing;

    const conversation = {
      id: `conversation-${this.conversations.size + 1}`,
      businessAccountId,
      externalConversationId,
      leadId: lead.id,
      ...createAiConversation(),
    };
    this.conversations.set(key, conversation);
    return conversation;
  }

  saveConversation(conversation) {
    this.conversations.set(`${conversation.businessAccountId}:${conversation.externalConversationId}`, conversation);
    return conversation;
  }

  getConversation({ businessAccountId, externalConversationId }) {
    return this.conversations.get(`${businessAccountId}:${externalConversationId}`) ?? null;
  }

  saveMessage(message) {
    if (this.messages.has(message.externalMessageId)) return false;
    this.messages.set(message.externalMessageId, message);
    return true;
  }

  recordAudit(event) {
    this.auditEvents.push(event);
  }

  listConversations() {
    return [...this.conversations.values()];
  }
}
