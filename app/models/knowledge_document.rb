# frozen_string_literal: true

# == Schema Information
#
# Table name: knowledge_documents
#
#  id                      :bigint           not null, primary key
#  archived_at             :datetime
#  body                    :text             default(""), not null
#  general_question_access :boolean          default(TRUE), not null
#  import_metadata         :jsonb            not null
#  offer_ids               :jsonb            not null
#  published_at            :datetime
#  published_content_digest :string
#  revisions               :jsonb            not null
#  sensitive_topics        :jsonb            not null
#  status                  :integer          default("draft"), not null
#  title                   :string           not null
#  used_by_ai_employee     :boolean          default(TRUE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  last_editor_id          :bigint
#
# Indexes
#
#  idx_on_account_id_status_updated_at_092c73be75  (account_id,status,updated_at)
#  index_knowledge_documents_on_account_id         (account_id)
#  index_knowledge_documents_on_last_editor_id     (last_editor_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (last_editor_id => users.id)
#
class KnowledgeDocument < ApplicationRecord
  belongs_to :account
  belongs_to :last_editor, class_name: 'User', optional: true

  enum status: {
    draft: 0,
    published: 1,
    archived: 2,
    import_failed: 3
  }

  validates :title, presence: true
  validates :body, presence: true, unless: :import_failed?
  validate :last_editor_belongs_to_account
  before_validation :record_initial_published_content_digest, on: :create

  scope :search, lambda { |query|
    next all if query.blank?

    normalized_query = "%#{sanitize_sql_like(query.to_s.downcase)}%"
    where('LOWER(title) LIKE :query OR LOWER(body) LIKE :query', query: normalized_query)
  }
  scope :eligible_for_ai_employee, -> { published.where(used_by_ai_employee: true, general_question_access: true) }

  def publish!(editor:)
    append_revision!(editor: editor, event: 'published')
    self.status = :published
    self.published_at = Time.current
    self.published_content_digest = content_digest
    self.archived_at = nil
    self.last_editor = editor
    save!
  end

  def archive!(editor:)
    append_revision!(editor: editor, event: 'archived')
    update!(status: :archived, archived_at: Time.current, last_editor: editor)
  end

  def save_draft!(attributes:, editor:)
    assign_attributes(attributes.merge(status: :draft, last_editor: editor))
    append_revision!(editor: editor, event: persisted? ? 'draft_saved' : 'created')
    save!
  end

  def test_answer(question)
    AiLeadEmployee::KnowledgeAnswerService.new(account: account, question: question, document_scope: self).perform
  end

  def source_reference
    return if published_at.blank?

    "knowledge_document:#{id}:published_at:#{published_at.iso8601}:#{published_content_digest}"
  end

  def verified_source_reference?
    published? &&
      archived_at.blank? &&
      published_at.present? &&
      published_content_digest.present? &&
      ActiveSupport::SecurityUtils.secure_compare(published_content_digest, content_digest) &&
      used_by_ai_employee? &&
      general_question_access?
  end

  private

  def content_digest
    Digest::SHA256.hexdigest(
      [title, body, used_by_ai_employee, general_question_access, Array(offer_ids), Array(sensitive_topics)].to_json
    )
  end

  def record_initial_published_content_digest
    self.published_content_digest = content_digest if published? && published_content_digest.blank?
  end

  def append_revision!(editor:, event:)
    self.revisions = Array(revisions) + [
      {
        event: event,
        title: title,
        status: status,
        editor_id: editor&.id,
        editor_name: editor&.name,
        recorded_at: Time.current.iso8601
      }.compact
    ]
  end

  def last_editor_belongs_to_account
    return if last_editor.blank?
    return if last_editor.account_users.exists?(account_id: account_id)

    errors.add(:last_editor, 'must belong to the document account')
  end
end
