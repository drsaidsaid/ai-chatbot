class Whatsapp::ReceiptProcessor
  EVENT_ARRAYS = %w[messages message_echoes statuses].freeze

  def initialize(receipt)
    @receipt = receipt
  end

  def perform
    expand
    @receipt.events.order(:id).each { |event| Whatsapp::EventProcessor.new(event).perform }
  end

  private

  def expand
    @receipt.with_lock do
      return if @receipt.expanded_at?

      payload = JSON.parse(@receipt.raw_body)
      @receipt.verified_routes.each do |route|
        change = payload.fetch('entry').fetch(route.fetch('entry')).fetch('changes').fetch(route.fetch('change'))
        expand_change(route, change)
      end
      @receipt.update!(expanded_at: Time.current, error_code: nil)
    end
  end

  def expand_change(route, change)
    EVENT_ARRAYS.each do |kind|
      Array(change.dig('value', kind)).each do |item|
        create_event(route, change, kind, item)
      end
    end
  end

  def create_event(route, change, kind, item)
    identity = [kind, item['id']]
    identity += [item['status'], item['timestamp'], item['errors']] if kind == 'statuses'
    identity << item if item['id'].blank?
    key = Digest::SHA256.hexdigest(identity.to_json)
    Whatsapp::WebhookEvent.create_or_find_by!(channel_id: route.fetch('channel_id'), event_key: key) do |event|
      event.assign_attributes(
        receipt: @receipt, account_id: route.fetch('account_id'), inbox_id: route.fetch('inbox_id'),
        kind: kind, provider_message_id: item['id'], provider_created_at: provider_time(item['timestamp']),
        payload: single_event_payload(change, kind, item)
      )
    end
  end

  def single_event_payload(change, kind, item)
    value = change.fetch('value').except(*EVENT_ARRAYS).merge(kind => [item])
    value['contacts'] = [matching_contact(value['contacts'], item, kind)].compact
    { object: 'whatsapp_business_account', entry: [{ changes: [{ field: change['field'], value: value }] }] }
  end

  def matching_contact(contacts, item, kind)
    return if kind == 'message_echoes'

    prefix = kind == 'statuses' ? 'recipient' : 'from'
    identifiers = [item[prefix], item["#{prefix}_id"], item["#{prefix}_user_id"], item["#{prefix}_parent_user_id"]].compact_blank
    match = Array(contacts).find { |contact| contact.values_at('wa_id', 'user_id', 'parent_user_id').compact_blank.intersect?(identifiers) }
    return match if match
    return if kind == 'statuses'

    { 'wa_id' => item['from'], 'user_id' => item['from_user_id'], 'parent_user_id' => item['from_parent_user_id'] }.compact
  end

  def provider_time(value)
    Time.at(Integer(value)).utc
  rescue ArgumentError, TypeError, RangeError
    nil
  end
end
