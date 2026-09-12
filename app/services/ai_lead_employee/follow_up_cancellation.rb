# frozen_string_literal: true

class AiLeadEmployee::FollowUpCancellation
  def self.call(follow_ups:, reason:, conversation_scope: nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # Standalone after-commit/opt-out callers acquire the origin prefix afresh.
    # Batch callers that already own Conversations use cancel_locked! below.
    ApplicationRecord.transaction do
      rows = conversation_scope ? [] : follow_ups.to_a
      conversations_to_lock = conversation_scope || Conversation.where(id: rows.map(&:conversation_id))
      conversations = conversations_to_lock.order(:id).lock('FOR NO KEY UPDATE').to_a

      follow_ups_to_cancel = if conversation_scope
                               conversation_ids = conversations.map(&:id)
                               account_ids = conversations.map(&:account_id).uniq
                               if account_ids.empty? || conversation_ids.empty?
                                 []
                               else
                                 follow_ups.where(account_id: account_ids, conversation_id: conversation_ids, status: %i[pending cancelled]).to_a
                               end
                             else
                               rows
                             end

      lock_offers!(conversations: conversations, follow_ups: follow_ups_to_cancel)
      Whatsapp::DeliveryLifecycle.with(follow_ups: LeadFollowUp.where(id: follow_ups_to_cancel.map(&:id))) do |owner|
        delivery_reason = LeadFollowUp::CONTEXT_REPLACEMENT_REASONS.include?(reason) ? reason : 'follow_up_canceled'
        owner.follow_ups.each_value { |follow_up| owner.cancel_artifact!(follow_up, reason: reason, delivery_reason: delivery_reason) }
      end
    end
  end

  def self.lock_offers!(conversations:, follow_ups:, additional_offer_ids: [])
    ids = conversations.map(&:offer_id) + follow_ups.map { |f| f.qualification_context['offer_id'] } + additional_offer_ids
    AiLeadEmployee::Offer.where(account_id: conversations.map(&:account_id).uniq, id: ids.compact).order(:id).lock('FOR NO KEY UPDATE').load
  end
end
