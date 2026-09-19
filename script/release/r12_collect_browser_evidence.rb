# frozen_string_literal: true

require 'digest'
require 'json'

database = ActiveRecord::Base.connection_db_config.database
allowed_database = ENV.fetch('R12_BROWSER_DATABASE', nil)
abort 'Disposable R12 browser database only' unless Rails.env.test? && database == allowed_database &&
                                                    database&.match?(/\Aale_r12_[a-z0-9_]+_browser\z/)

def canonical_json(value)
  deep_sort = lambda do |entry|
    case entry
    when Hash
      entry.keys.sort.index_with { |key| deep_sort.call(entry.fetch(key)) }
    when Array
      entry.map { |item| deep_sort.call(item) }
    else
      entry
    end
  end
  JSON.generate(deep_sort.call(value))
end

account = Account.find_by!(name: 'R12 Synthetic Review Business')
offer = AiLeadEmployee::Offer.find_by!(account_id: account.id, id: ENV.fetch('R12_BROWSER_OFFER_ID'))
reviews = HumanReviewRequest.where(account: account).order(:id)

puts JSON.pretty_generate(
  database: database,
  account_id: account.id,
  offer: {
    id: offer.id,
    configuration_version: offer.configuration_version,
    configuration_digest: Digest::SHA256.hexdigest(canonical_json(offer.configuration))
  },
  reviews: reviews.map do |review|
    {
      id: review.id,
      conversation_id: review.conversation_id,
      status: review.status,
      resolution_kind: review.resolution_kind,
      operator_answer: review.operator_answer,
      human_answer_message: review.human_answer_message&.slice(:id, :message_type, :private, :status, :content),
      knowledge_item: review.knowledge_item&.slice(:id, :status, :source_kind, :question, :answer, :approved_at, :metadata),
      configuration_suggestion: review.configuration_suggestion&.slice(
        :id, :category, :status, :suggestion, :evidence, :source_message_id, :reviewed_by_user_id, :reviewed_at, :decision_note
      ),
      conversation_messages: review.conversation.messages.order(:id).map do |message|
        message.slice(:id, :message_type, :private, :status, :content, :sender_type, :sender_id)
      end
    }
  end,
  handoffs: LeadHandoff.where(account: account).order(:id).map do |handoff|
    {
      id: handoff.id,
      conversation_id: handoff.conversation_id,
      status: handoff.status,
      qualification_snapshot: handoff.qualification_snapshot,
      configuration_suggestion: handoff.configuration_suggestion&.slice(
        :id, :category, :status, :suggestion, :evidence, :offer_id, :reviewed_by_user_id, :reviewed_at, :decision_note
      )
    }
  end
)
