# frozen_string_literal: true

# Presents one authoritative template catalogue to Inbox pickers and the final
# send path. An owned template name shadows the provider cache even while its
# current revision is not sendable, preventing stale approvals from escaping.
class Whatsapp::TemplateCatalog
  def self.for_channel(channel)
    new(channel).templates
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

  private

  def legacy_templates = Array(@channel.message_templates)

  def serialize(template)
    revision = template.latest_revision
    return unless revision&.sendable?

    {
      'id' => revision.provider_template_id,
      'name' => template.name,
      'language' => revision.language,
      'category' => revision.category,
      'status' => 'APPROVED',
      'components' => components(revision)
    }
  end

  def components(revision)
    [{ 'type' => 'BODY', 'text' => revision.body }].tap do |items|
      items << revision.media.merge('type' => 'HEADER') if revision.media.present?
      items << { 'type' => 'BUTTONS', 'buttons' => revision.buttons } if revision.buttons.present?
    end
  end
end
