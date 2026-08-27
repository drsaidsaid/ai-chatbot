# frozen_string_literal: true

class AddPublishedContentDigestToKnowledgeDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :knowledge_documents, :published_content_digest, :string
  end
end
