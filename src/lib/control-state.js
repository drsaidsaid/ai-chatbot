export const ControlState = Object.freeze({
  AI_ACTIVE: "ai_active",
  HANDOFF_REQUESTED: "handoff_requested",
  HUMAN_ACTIVE: "human_active",
  AI_PAUSED: "ai_paused",
  CLOSED: "closed",
});

export const ChatwootStatus = Object.freeze({
  PENDING: "pending",
  OPEN: "open",
  RESOLVED: "resolved",
});

export const Owner = Object.freeze({
  AI: "ai_employee",
  HUMAN: "human_operator",
  NONE: "none",
});

export function createAiConversation(overrides = {}) {
  return {
    controlState: ControlState.AI_ACTIVE,
    chatwootStatus: ChatwootStatus.PENDING,
    currentOwner: Owner.AI,
    controlVersion: 1,
    aiReplyQueued: false,
    followUpQueued: false,
    ...overrides,
  };
}

function humanOwnsConversation(conversation) {
  return {
    ...conversation,
    controlState: ControlState.HUMAN_ACTIVE,
    chatwootStatus: ChatwootStatus.OPEN,
    currentOwner: Owner.HUMAN,
    aiReplyQueued: false,
    followUpQueued: false,
    controlVersion: conversation.controlVersion + 1,
  };
}

export function transitionConversation(conversation, event) {
  switch (event.type) {
    case "lead_message":
      if (conversation.controlState === ControlState.CLOSED) {
        return {
          ...conversation,
          controlState: ControlState.AI_ACTIVE,
          chatwootStatus: ChatwootStatus.PENDING,
          currentOwner: Owner.AI,
          controlVersion: conversation.controlVersion + 1,
          aiReplyQueued: true,
          followUpQueued: false,
        };
      }

      return conversation.controlState === ControlState.AI_ACTIVE
        ? { ...conversation, aiReplyQueued: true }
        : conversation;

    case "ai_handoff":
      return {
        ...conversation,
        controlState: ControlState.HANDOFF_REQUESTED,
        chatwootStatus: ChatwootStatus.OPEN,
        currentOwner: Owner.NONE,
        aiReplyQueued: false,
        followUpQueued: false,
        controlVersion: conversation.controlVersion + 1,
      };

    case "human_assigned":
    case "human_reply":
      return humanOwnsConversation(conversation);

    case "manual_pause":
      return {
        ...conversation,
        controlState: ControlState.AI_PAUSED,
        currentOwner: Owner.NONE,
        aiReplyQueued: false,
        followUpQueued: false,
        controlVersion: conversation.controlVersion + 1,
      };

    case "manual_resume":
      if (
        conversation.controlState !== ControlState.AI_PAUSED &&
        conversation.controlState !== ControlState.HUMAN_ACTIVE
      ) {
        return conversation;
      }

      return {
        ...conversation,
        controlState: ControlState.AI_ACTIVE,
        chatwootStatus: ChatwootStatus.PENDING,
        currentOwner: Owner.AI,
        aiReplyQueued: false,
        controlVersion: conversation.controlVersion + 1,
      };

    case "resolve":
      return {
        ...conversation,
        controlState: ControlState.CLOSED,
        chatwootStatus: ChatwootStatus.RESOLVED,
        currentOwner: Owner.NONE,
        aiReplyQueued: false,
        followUpQueued: false,
        controlVersion: conversation.controlVersion + 1,
      };

    default:
      return conversation;
  }
}

export function maySendAiReply(conversation) {
  return (
    conversation.controlState === ControlState.AI_ACTIVE &&
    conversation.chatwootStatus === ChatwootStatus.PENDING &&
    conversation.currentOwner === Owner.AI
  );
}
