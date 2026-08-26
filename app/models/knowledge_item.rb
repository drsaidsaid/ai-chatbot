# frozen_string_literal: true

class KnowledgeItem < ApplicationRecord
  belongs_to :account

  enum source_kind: {
    faq: 0,
    offer: 1,
    pricing: 2,
    supporting_document: 3
  }
  enum status: {
    draft: 0,
    approved: 1,
    rejected: 2,
    inactive: 3
  }

  validates :title, :question, :answer, :source_kind, :status, presence: true

  scope :usable_by_ai_employee, -> { approved.where(deactivated_at: nil) }

  def approve!
    update!(status: :approved, approved_at: Time.current, rejected_at: nil, deactivated_at: nil)
  end

  def reject!
    update!(status: :rejected, rejected_at: Time.current, deactivated_at: nil)
  end

  def deactivate!
    update!(status: :inactive, deactivated_at: Time.current)
  end
end
