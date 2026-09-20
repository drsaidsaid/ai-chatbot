# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerOrchestrationIntent < AiLeadEmployee::AiProviderLedgerRecord
  self.table_name = 'ai_orchestration_intents'

  def exact_pilot_scope?(pilot) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    conversation = AiLeadEmployee::AiProviderLedgerConversation.find_by(id: conversation_id)
    message = AiLeadEmployee::AiProviderLedgerMessage.find_by(id: triggering_message_id)
    contact_inbox = AiLeadEmployee::AiProviderLedgerContactInbox.find_by(contact_id: pilot.contact_id, inbox_id: pilot.inbox_id)
    pilot_authorization_id == pilot.id && account_id == pilot.account_id && observed_control_version == pilot.control_version &&
      conversation&.account_id == pilot.account_id && conversation&.inbox_id == pilot.inbox_id && conversation&.contact_id == pilot.contact_id &&
      conversation&.control_version == pilot.control_version && message&.account_id == pilot.account_id &&
      message&.conversation_id == pilot.conversation_id && message&.inbox_id == pilot.inbox_id && message&.message_type&.zero? &&
      message&.sender_id == pilot.contact_id && contact_inbox&.source_id.to_s == pilot.recipient
  end
end
