# frozen_string_literal: true

class AiLeadEmployee::BusinessSetupSource < ApplicationRecord
  class Conflict < StandardError; end
  class NotAuthorized < StandardError; end

  self.table_name = 'business_setup_sources'

  belongs_to :account
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer'
  belongs_to :knowledge_document, optional: true
  belongs_to :published_by, class_name: 'User', optional: true

  enum status: { proposed: 0, published: 1 }

  validates :title, :source_type, :body, presence: true
  validates :source_type, inclusion: { in: %w[pasted_prose document] }
  validate :same_business_account
  validate :same_knowledge_account

  def payload
    proposal_data = proposal.to_h
    {
      id: id, offer_id: offer_id, title: title, source_type: source_type, body: body,
      status: status, version: version, source_path: "/business-setup-sources/#{id}",
      proposed_facts: proposal_data.fetch('facts', []), proposed_rules: proposal_data.fetch('rules', []),
      unknowns: proposal_data.fetch('unknowns', []), configuration: proposal_data.fetch('configuration', {}),
      history: history, knowledge_document_id: knowledge_document_id,
      published_offer_version: published_offer_version, published_at: published_at
    }
  end

  def current_published_offer?
    published? && published_offer_version == offer.configuration_version && knowledge_document&.verified_source_reference?
  end

  def initialize_history!(editor:)
    self.history = [revision_snapshot(event: 'proposed', editor: editor)]
  end

  def replace_proposal!(attributes:, expected_source_version:, editor:)
    transaction do
      lock_administrator!(editor)
      lock!
      offer.lock!
      raise Conflict, 'This setup source has already been published' if published?
      raise Conflict, 'Setup source changed; reload before saving' unless version == expected_source_version.to_i

      assign_attributes(attributes.slice(:title, :source_type, :body))
      self.proposal = proposal_for(attributes[:reviewed_configuration] || offer.payload)
      self.version += 1
      self.history = history + [revision_snapshot(event: 'corrected', editor: editor)]
      save!
    end
  end

  def publish!(expected_source_version:, expected_offer_version:, editor:)
    transaction do
      # Canonical writer prefix: Knowledge authority, Account key-share, membership, source, Offer.
      AiLeadEmployee::KnowledgeAuthorityLock.acquire_for_answer!(account_id)
      lock_administrator!(editor)
      lock!
      offer.lock!
      ensure_current!(expected_source_version, expected_offer_version)
      ensure_qualification_action_is_resolved!
      finalize_publication!(editor)
    end
  end

  private

  def proposal_for(reviewed_configuration)
    AiLeadEmployee::BusinessSetupProposalExtractor.new(
      offer: offer, body: body, reviewed_configuration: reviewed_configuration, previous_proposal: proposal
    ).perform
  end

  def lock_administrator!(editor)
    membership = AccountUser.lock.find_by(account_id: account_id, user_id: editor.id)
    raise NotAuthorized, 'Administrator access is required' unless membership&.administrator?
  end

  def same_business_account
    errors.add(:offer, 'must belong to this Business Account') unless offer&.account_id == account_id
  end

  def same_knowledge_account
    return if knowledge_document.blank? || knowledge_document.account_id == account_id

    errors.add(:knowledge_document, 'must belong to this Business Account')
  end

  def ensure_current!(expected_source_version, expected_offer_version)
    raise Conflict, 'This setup source has already been published' if published?
    raise Conflict, 'Setup source changed; reload before publishing' unless version == expected_source_version.to_i
    raise Conflict, 'Offer configuration changed; review the preview again' unless offer.configuration_version == expected_offer_version.to_i
    return if proposal.dig('configuration', 'version').to_i == expected_offer_version.to_i

    raise Conflict, 'Reviewed configuration is stale; reload and create a new preview'
  end

  def ensure_qualification_action_is_resolved!
    return unless proposal['qualification_clarification_required'] || AiLeadEmployee::BusinessSetupQualificationProposal.any_complex_text?(body)
    return unless proposal.dig('configuration', 'qualification_mode') == 'enabled'
    return unless proposal.dig('configuration', 'next_step', 'kind') == 'sales_call'

    raise Conflict, 'Clarify the qualification alternatives before publishing a sales-call setup'
  end

  def finalize_publication!(editor)
    published_offer = publish_offer_configuration!
    document = publish_knowledge_document!(editor)
    supersede_previous_documents!(document, editor)
    record_publication!(published_offer, document, editor)
  rescue AiLeadEmployee::OfferConfigurationWriter::Conflict => e
    raise Conflict, e.message
  end

  def publish_offer_configuration!
    configuration = proposal.fetch('configuration').merge('version' => offer.configuration_version)
    AiLeadEmployee::OfferConfigurationWriter.new(offer: offer, attributes: configuration).perform
  end

  def record_publication!(published_offer, document, editor)
    self.status = :published
    self.knowledge_document = document
    self.published_by = editor
    self.published_at = Time.current
    self.published_offer_version = published_offer.configuration_version
    self.history = history + [revision_snapshot(event: 'published', editor: editor).merge(
      'offer_version' => published_offer_version, 'knowledge_document_id' => document.id
    )]
    save!
  end

  def publish_knowledge_document!(editor)
    document = account.knowledge_documents.new
    document.save_draft!(attributes: knowledge_attributes(body), editor: editor)
    AiLeadEmployee::CommercialProposalExtractor.new(document: document, offer: offer).perform
    approved_body = proposal.fetch('knowledge_body').to_s
    raise ArgumentError, 'Add a non-price business fact before publishing' if approved_body.blank?

    document.save_draft!(attributes: knowledge_attributes(approved_body), editor: editor)
    document.publish!(editor: editor)
    document
  end

  def knowledge_attributes(document_body)
    {
      title: title, body: document_body, used_by_ai_employee: true,
      general_question_access: false, offer_ids: [offer_id], sensitive_topics: []
    }
  end

  def supersede_previous_documents!(document, editor)
    account.business_setup_sources.published.where(offer_id: offer_id).where.not(knowledge_document_id: nil)
           .where.not(knowledge_document_id: document.id).includes(:knowledge_document).find_each do |source|
      source.knowledge_document.archive!(editor: editor) if source.knowledge_document.published?
    end
  end

  def revision_snapshot(event:, editor:)
    snapshot = {
      'event' => event, 'version' => version, 'title' => title, 'source_type' => source_type,
      'body' => body, 'proposal' => proposal.deep_dup, 'status' => status,
      'editor_id' => editor.id, 'recorded_at' => Time.current.iso8601
    }
    snapshot.merge('digest' => Digest::SHA256.hexdigest(snapshot.except('recorded_at').to_json))
  end
end
