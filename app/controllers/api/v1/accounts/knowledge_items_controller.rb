# frozen_string_literal: true

class Api::V1::Accounts::KnowledgeItemsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :knowledge_item, only: [:show, :update, :destroy, :approve, :reject, :deactivate]

  def index
    items = current_account.knowledge_items.order(updated_at: :desc)
    render json: items.map { |item| payload(item, items: items) }
  end

  def show
    render json: payload(@knowledge_item, items: current_account.knowledge_items)
  end

  def create
    item = current_account.knowledge_items.create!(knowledge_item_params)
    render json: payload(item, items: current_account.knowledge_items), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    @knowledge_item.update!(knowledge_item_params)
    render json: payload(@knowledge_item, items: current_account.knowledge_items)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @knowledge_item.destroy!
    head :ok
  end

  def approve
    @knowledge_item.approve!
    render json: payload(@knowledge_item, items: current_account.knowledge_items)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :conflict
  end

  def reject
    @knowledge_item.reject!
    render json: payload(@knowledge_item, items: current_account.knowledge_items)
  end

  def deactivate
    @knowledge_item.deactivate!
    render json: payload(@knowledge_item, items: current_account.knowledge_items)
  end

  private

  def knowledge_item
    @knowledge_item = current_account.knowledge_items.find(params[:id])
  end

  def knowledge_item_params
    params.permit(:title, :question, :answer, :source_kind, metadata: {})
  end

  def payload(item, items:)
    conflicts = items.select do |candidate|
      candidate.id != item.id &&
        candidate.status == item.status &&
        candidate.source_kind == item.source_kind &&
        candidate.conflict_key == item.conflict_key &&
        candidate.answer.to_s.squish != item.answer.to_s.squish
    end

    item.as_json.merge(
      'conflict_count' => conflicts.size,
      'conflict_ids' => conflicts.map(&:id)
    )
  end
end
