# frozen_string_literal: true

class Api::V1::Accounts::KnowledgeDocumentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :knowledge_document, only: [:show, :update, :destroy, :publish, :archive, :test]

  def index
    documents = current_account.knowledge_documents.search(params[:q]).order(updated_at: :desc)
    render json: documents.map { |document| payload(document, include_body: true) }
  end

  def show
    render json: payload(@knowledge_document, include_body: true)
  end

  def create
    document = current_account.knowledge_documents.new
    KnowledgeDocument.transaction do
      document.save_draft!(attributes: knowledge_document_params, editor: Current.user)
      extract_commercial_proposals(document)
    end
    render json: payload(document, include_body: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    KnowledgeDocument.transaction do
      @knowledge_document.save_draft!(attributes: knowledge_document_params, editor: Current.user)
      extract_commercial_proposals(@knowledge_document)
    end
    render json: payload(@knowledge_document.reload, include_body: true)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @knowledge_document.destroy!
    head :ok
  end

  def import
    document = current_account.knowledge_documents.new(import_document_attributes)
    KnowledgeDocument.transaction do
      document.import_metadata = import_metadata(document)
      document.status = document.body.present? ? :draft : :import_failed
      document.revisions = [{ event: 'imported', editor_id: Current.user&.id, recorded_at: Time.current.iso8601 }]
      document.save!
      extract_commercial_proposals(document)
    end
    render json: payload(document, include_body: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def publish
    @knowledge_document.publish!(editor: Current.user)
    render json: payload(@knowledge_document.reload, include_body: true)
  end

  def archive
    @knowledge_document.archive!(editor: Current.user)
    render json: payload(@knowledge_document.reload, include_body: true)
  end

  def test
    result = @knowledge_document.test_answer(params[:question])
    render json: {
      answer: result.answer,
      answered: result.answered?,
      refusal_reason: result.refusal_reason,
      sources: result.sources
    }
  end

  private

  def knowledge_document
    @knowledge_document = current_account.knowledge_documents.find(params[:id])
  end

  def selected_import_offer
    return if params[:offer_id].blank?

    @selected_import_offer ||= current_account.qualification_offers.find(params[:offer_id])
  end

  def import_document_attributes
    scope = selected_import_offer ? { offer_ids: [selected_import_offer.id], general_question_access: false } : {}
    import_document_params.merge(scope).merge(last_editor: Current.user)
  end

  def extract_commercial_proposals(document)
    return if document.body.blank?

    current_account.qualification_offers.where(id: Array(document.offer_ids)).find_each do |offer|
      AiLeadEmployee::CommercialProposalExtractor.new(document: document, offer: offer).perform
    end
  end

  def knowledge_document_params
    params.permit(
      :title,
      :body,
      :used_by_ai_employee,
      :general_question_access,
      offer_ids: [],
      sensitive_topics: []
    )
  end

  def import_document_params
    params.permit(:title, :body)
  end

  def import_metadata(document)
    {
      status: document.body.present? ? 'completed' : 'failed',
      source: params[:source].presence || 'manual_import',
      imported_at: Time.current.iso8601,
      error: document.body.present? ? nil : 'Document body could not be read'
    }.compact
  end

  def payload(document, include_body: false)
    {
      id: document.id,
      title: document.title,
      body: include_body ? document.body : document.body.to_s.truncate(220),
      status: document.status,
      used_by_ai_employee: document.used_by_ai_employee,
      general_question_access: document.general_question_access,
      offer_ids: document.offer_ids,
      sensitive_topics: document.sensitive_topics,
      import_metadata: document.import_metadata,
      revisions: document.revisions,
      published_at: document.published_at,
      archived_at: document.archived_at,
      updated_at: document.updated_at,
      last_editor: document.last_editor && { id: document.last_editor.id, name: document.last_editor.name },
      commercial_proposals: document.commercial_proposals.order(created_at: :desc).map(&:payload)
    }
  end
end
