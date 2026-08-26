# frozen_string_literal: true

class Api::V1::Accounts::QualificationConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: configuration_payload
  end

  def update
    ActiveRecord::Base.transaction do
      update_questions!
      update_budget_ranges!
      bump_configuration_version!
    end

    render json: configuration_payload
  end

  private

  def update_questions!
    Array(params[:questions]).each do |question_params|
      attributes = question_params.permit(:id, :signal, :prompt, :position, :enabled, metadata: {})
      question = qualification_question_for(attributes[:id])
      question.update!(attributes.except(:id))
    end
  end

  def update_budget_ranges!
    Array(params[:budget_ranges]).each do |range_params|
      attributes = range_params.permit(:id, :label, :min_cents, :max_cents, :position, :enabled)
      range = qualification_budget_range_for(attributes[:id])
      range.update!(attributes.except(:id))
    end
  end

  def bump_configuration_version!
    version = current_account.settings.fetch('qualification_config_version', 1).to_i + 1
    current_account.update!(settings: current_account.settings.merge('qualification_config_version' => version))
  end

  def configuration_payload
    {
      version: current_account.settings.fetch('qualification_config_version', 1).to_i,
      questions: current_account.qualification_questions.order(:position, :id).as_json(only: [:id, :signal, :prompt, :position, :enabled, :metadata]),
      budget_ranges: current_account.qualification_budget_ranges.order(:position, :id).as_json(
        only: [:id, :label, :min_cents, :max_cents, :position, :enabled]
      )
    }
  end

  def qualification_question_for(id)
    id.present? ? current_account.qualification_questions.find(id) : current_account.qualification_questions.new
  end

  def qualification_budget_range_for(id)
    id.present? ? current_account.qualification_budget_ranges.find(id) : current_account.qualification_budget_ranges.new
  end
end
