# frozen_string_literal: true

class Api::V1::Accounts::WhatsappTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :template, only: %i[show update submit reconcile]

  def index
    render json: current_account.whatsapp_templates.includes(:revisions).order(updated_at: :desc).map { |record| payload(record) }
  end

  def show
    render json: payload(@template)
  end

  def create
    channel = current_account.whatsapp_channels.find_by!(inbox: current_account.inboxes.find(template_params.fetch(:inbox_id)))
    raise ActiveRecord::RecordNotFound unless channel.provider == 'whatsapp_cloud'

    record = ActiveRecord::Base.transaction do
      created = current_account.whatsapp_templates.create!(channel: channel, created_by: Current.user, name: template_params.fetch(:name))
      create_revision!(created)
      created
    end
    render json: payload(record), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    create_revision!(@template)
    render json: payload(@template)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def submit
    revision = @template.latest_revision
    return render json: { error: 'Only a local draft can be submitted.' }, status: :conflict unless revision&.draft?

    revision.update!(status: :submission_pending, submitted_at: Time.current, submitted_by: Current.user)
    Whatsapp::TemplateSubmissionJob.perform_later(revision)
    render json: payload(@template), status: :accepted
  end

  def reconcile
    revision = @template.latest_revision
    return render json: { error: 'Only a submitted template can be reconciled.' }, status: :conflict unless revision&.submitted_at?

    Whatsapp::TemplateSubmissionJob.perform_later(revision, reconcile: true)
    render json: payload(@template), status: :accepted
  end

  private

  def template = @template = current_account.whatsapp_templates.find(params[:id])

  def template_params
    params.permit(:inbox_id, :name, :language, :category, :body, media: {}, buttons: %i[type text url], variables: %i[position example],
                                                                 meta_charge_estimate: %i[amount currency market effective_on source])
  end

  # rubocop:disable Metrics/AbcSize
  def create_revision!(record)
    previous = record.latest_revision
    revision = record.revisions.build(
      account: current_account, channel: record.channel, revision_number: previous ? previous.revision_number + 1 : 1,
      language: template_params.fetch(:language), category: template_params.fetch(:category), body: template_params.fetch(:body),
      media: template_params[:media] || {}, buttons: template_params[:buttons] || [], variables: template_params[:variables] || [],
      meta_charge_estimate: template_params[:meta_charge_estimate] || {}, submission_key: SecureRandom.uuid
    )
    revision.content_digest = Digest::SHA256.hexdigest(revision.preview.to_json)
    revision.save!
  end
  # rubocop:enable Metrics/AbcSize

  def payload(record)
    revision = record.latest_revision
    {
      id: record.id, inbox_id: record.channel.inbox&.id, name: record.name, revision: revision.revision_number,
      language: revision.language, category: revision.category, status: revision.status, meta_approval: revision.meta_approval,
      provider_template_id: revision.provider_template_id, rejection_reason: revision.rejection_reason,
      last_sync_at: revision.status_synced_at, preview: revision.preview,
      meta_charge_estimate: revision.meta_charge_estimate.presence,
      meta_charge_status: revision.meta_charge_estimate.present? ? 'available' : 'unknown',
      sendable: revision.sendable?
    }
  end
end
