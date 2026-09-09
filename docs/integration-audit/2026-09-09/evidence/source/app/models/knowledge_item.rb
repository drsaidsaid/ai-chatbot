# frozen_string_literal: true

# == Schema Information
#
# Table name: knowledge_items
#
#  id             :bigint           not null, primary key
#  answer         :text             not null
#  approved_at    :datetime
#  deactivated_at :datetime
#  metadata       :jsonb            not null
#  question       :text             not null
#  rejected_at    :datetime
#  source_kind    :integer          default("faq"), not null
#  status         :integer          default("draft"), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_knowledge_items_on_account_id                             (account_id)
#  index_knowledge_items_on_account_id_and_status_and_source_kind  (account_id,status,source_kind)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KnowledgeItem < ApplicationRecord
  belongs_to :account

  enum source_kind: {
    faq: 0,
    offer: 1,
    pricing: 2,
    supporting_document: 3,
    objection: 4,
    policy: 5,
    refund: 6,
    guarantee: 7,
    eligibility: 8
  }
  enum status: {
    draft: 0,
    approved: 1,
    rejected: 2,
    inactive: 3
  }

  validates :title, :question, :answer, :source_kind, :status, presence: true

  scope :usable_by_ai_employee, -> { approved.where(deactivated_at: nil) }
  scope :sensitive_claims, -> { where(source_kind: [:pricing, :refund, :guarantee, :eligibility, :policy]) }

  def source_reference
    metadata['source_reference'].presence
  end

  def stale?
    return true if ActiveModel::Type::Boolean.new.cast(metadata['stale'])
    return false if metadata['expires_at'].blank?

    Time.zone.parse(metadata['expires_at'].to_s) <= Time.current
  rescue ArgumentError, TypeError
    true
  end

  def verified_source_reference?
    approved? &&
      deactivated_at.blank? &&
      approved_at.present? &&
      updated_at <= approved_at + 1.second &&
      source_reference.present? &&
      !stale?
  end

  def approve!
    now = Time.current
    self.metadata = metadata.merge('source_reference' => next_source_reference(now))
    update!(status: :approved, approved_at: now, rejected_at: nil, deactivated_at: nil, updated_at: now)
  end

  def reject!
    update!(status: :rejected, rejected_at: Time.current, deactivated_at: nil)
  end

  def deactivate!
    update!(status: :inactive, deactivated_at: Time.current)
  end

  def conflict_key
    question.to_s.downcase.gsub(/[^a-z0-9\s]/, ' ').squish
  end

  private

  def approval_source_reference(approved_at)
    "knowledge_item:#{id}:approved_at:#{approved_at.iso8601}"
  end

  def next_source_reference(approved_at)
    return source_reference if source_reference.present? && !source_reference.start_with?("knowledge_item:#{id}:approved_at:")

    approval_source_reference(approved_at)
  end
end
