# frozen_string_literal: true

# Presents one authoritative template catalogue to Inbox pickers and the final
# send path. An owned template name shadows the provider cache even while its
# current revision is not sendable, preventing stale approvals from escaping.
class Whatsapp::TemplateCatalog
  PROVIDER_STATES = %w[APPROVED REJECTED PAUSED DISABLED].freeze

  def self.for_channel(channel)
    new(channel).templates
  end

  def self.resolve(channel:, selection:)
    new(channel).resolve(selection)
  end

  def initialize(channel)
    @channel = channel
  end

  def templates
    return legacy_templates unless @channel.is_a?(Channel::Whatsapp) && @channel.persisted?

    owned = WhatsappTemplate.where(account_id: @channel.account_id, channel_id: @channel.id).includes(:revisions)
    owned_names = owned.pluck(:name)
    legacy = legacy_templates.reject { |template| owned_names.include?(template['name']) }

    legacy + owned.filter_map { |template| serialize(template) }
  end

  def resolve(selection)
    selected = selection.to_h.with_indifferent_access
    candidate = selected_candidate(selected)
    return unless approved?(candidate)
    return candidate unless candidate['owned_revision_id']
    return candidate if owned_identity_matches?(candidate, selected)
  end

  private

  def legacy_templates = Array(@channel.message_templates)

  def serialize(template)
    revision = template.latest_revision
    return if revision&.provider_template_id.blank?

    status = projected_status(revision)
    return unless PROVIDER_STATES.include?(status)

    {
      'id' => revision.provider_template_id,
      'name' => template.name,
      'language' => revision.language,
      'category' => revision.category,
      'status' => status,
      'owned_revision_id' => revision.id,
      'owned_content_digest' => revision.content_digest,
      'provider_template_id' => revision.provider_template_id,
      'components' => components(revision)
    }
  end

  def projected_status(revision)
    local_status = revision.status.upcase
    return local_status unless local_status == 'APPROVED'

    provider_status = provider_status_for(revision)
    provider_status.present? && provider_status != 'APPROVED' ? provider_status : local_status
  end

  def provider_status_for(revision)
    provider = legacy_templates.find do |item|
      item['id'].to_s == revision.provider_template_id.to_s && item['name'] == revision.whatsapp_template.name &&
        item['language']&.casecmp?(revision.language)
    end
    provider&.dig('status')&.upcase
  end

  def selected_candidate(selected)
    templates.find do |template|
      template['name'] == selected[:name] && template['language']&.casecmp?(selected[:language].to_s)
    end
  end

  def approved?(candidate) = candidate&.dig('status')&.casecmp?('approved')

  def owned_identity_matches?(candidate, selected)
    candidate['owned_revision_id'].to_s == selected[:owned_revision_id].to_s &&
      candidate['owned_content_digest'] == selected[:owned_content_digest] &&
      candidate['provider_template_id'] == selected[:provider_template_id]
  end

  def components(revision)
    [{ 'type' => 'BODY', 'text' => revision.body }].tap do |items|
      items << revision.media.merge('type' => 'HEADER') if revision.media.present?
      items << { 'type' => 'BUTTONS', 'buttons' => revision.buttons } if revision.buttons.present?
    end
  end
end
