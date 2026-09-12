# frozen_string_literal: true

# A batch owns every Conversation first, every Offer next, then origin intents
# and the entire A/F/D/M/E suffix. Consent can prepare O before locking its R.
class AiLeadEmployee::AutomationCancellation
  def self.call(conversation:, reason:)
    ApplicationRecord.transaction do
      conversations = Conversation.where(account_id: conversation.account_id, id: conversation.id).lock('FOR NO KEY UPDATE').to_a
      plan = new(conversations: conversations)
      plan.lock_offers!
      plan.cancel!(reason: reason)
    end
  end

  def initialize(conversations:)
    @conversations = conversations
    ids = conversations.map(&:id)
    @follow_ups = LeadFollowUp.where(conversation_id: ids)
    @deliveries = Whatsapp::OutboundDelivery.joins(:message)
                                            .where(account_id: conversations.map(&:account_id).uniq, state: %w[pending claimed])
                                            .where('whatsapp_outbound_deliveries.conversation_id IN (:ids) OR ' \
                                                   "messages.additional_attributes #>> '{ai_lead_employee,origin_conversation_id}' IN (:text_ids)",
                                                   ids: ids, text_ids: ids.map(&:to_s))
                                            .where("messages.sender_type IS NULL OR messages.sender_type != 'User'")
  end

  def lock_offers!
    ids = @conversations.map(&:offer_id) + @follow_ups.map { |f| f.qualification_context['offer_id'] }
    @deliveries.includes(:message).to_a.each do |delivery|
      ids << delivery.message.additional_attributes.dig('ai_lead_employee', 'qualification_context', 'offer_id')
    end
    AiLeadEmployee::Offer.where(id: ids.compact).order(:id).lock('FOR NO KEY UPDATE').load
  end

  def cancel!(reason:)
    intents = AiLeadEmployee::OrchestrationIntent.where(conversation_id: @conversations.map(&:id), state: %i[pending processing])
                                                 .order(:id).lock('FOR NO KEY UPDATE').to_a
    Whatsapp::DeliveryLifecycle.with(deliveries: @deliveries, follow_ups: @follow_ups) do |owner|
      # Preserve the established delivery failure reason independently of the
      # artifact's more specific control/consent cancellation history.
      owner.deliveries.each_value { |delivery| owner.cancel_delivery!(delivery, reason: reason) }
      owner.follow_ups.each_value do |follow_up|
        conversation = @conversations.find { |row| row.id == follow_up.conversation_id }
        owner.cancel_artifact!(follow_up, reason: follow_up_reason(conversation, reason))
      end
      intents.each { |intent| intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current) }
    end
  end

  private

  def follow_up_reason(conversation, reason)
    return 'follow_up_opted_out' if reason == 'opted_out'
    return "conversation_#{conversation.status}" if conversation && (conversation.resolved? || conversation.snoozed?)
    return "control_state_#{conversation.control_state}" if conversation && !conversation.ai_active?

    reason
  end
end
