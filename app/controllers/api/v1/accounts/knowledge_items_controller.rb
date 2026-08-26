# frozen_string_literal: true

class Api::V1::Accounts::KnowledgeItemsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :knowledge_item, only: [:show, :update, :destroy, :approve, :reject, :deactivate]

  def index
    render json: current_account.knowledge_items.order(created_at: :desc)
  end

  def show
    render json: @knowledge_item
  end

  def create
    item = current_account.knowledge_items.create!(knowledge_item_params)
    render json: item, status: :created
  end

  def update
    @knowledge_item.update!(knowledge_item_params)
    render json: @knowledge_item
  end

  def destroy
    @knowledge_item.destroy!
    head :ok
  end

  def approve
    @knowledge_item.approve!
    render json: @knowledge_item
  end

  def reject
    @knowledge_item.reject!
    render json: @knowledge_item
  end

  def deactivate
    @knowledge_item.deactivate!
    render json: @knowledge_item
  end

  private

  def knowledge_item
    @knowledge_item = current_account.knowledge_items.find(params[:id])
  end

  def knowledge_item_params
    params.permit(:title, :question, :answer, :source_kind, metadata: {})
  end
end
