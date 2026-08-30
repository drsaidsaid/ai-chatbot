# frozen_string_literal: true

class KnowledgeItem < ApplicationRecord
  belongs_to :account

  enum source_kind: {
    faq: 0,
    offer: 1,
    pricing: 2,
    supporting_document: 3,
    objection: 4,
    policy: 5
  }
  enum status: {
    draft: 0,
    approved: 1,
    rejected: 2,
    inactive: 3
  }

  validates :title, :question, :answer, :source_kind, :status, presence: true

  scope :usable_by_ai_employee, -> { approved.where(deactivated_at: nil) }

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

  private

  def approval_source_reference(approved_at)
    "knowledge_item:#{id}:approved_at:#{approved_at.iso8601}"
  end

  def next_source_reference(approved_at)
    return source_reference if source_reference.present? && !source_reference.start_with?("knowledge_item:#{id}:approved_at:")

    approval_source_reference(approved_at)
  end
end
