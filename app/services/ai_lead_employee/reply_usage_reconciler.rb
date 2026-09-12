# frozen_string_literal: true

class AiLeadEmployee::ReplyUsageReconciler
  CONFIRMED_PROVIDER_STATUSES = %w[sent delivered read].freeze

  class << self
    def register_deliveries!(usage:, messages:, at: Time.current)
      raise ArgumentError, 'A logical reply must include at least one delivery part' if messages.empty?

      deliveries = deliveries_for(messages)
      unless deliveries.length == messages.length && deliveries.all? { |delivery| delivery.ai_reply_usage_id == usage.id }
        raise ArgumentError, 'Every logical reply part must have a delivery linked to the same allowance reservation'
      end

      usage.with_lock do
        usage.update!(expected_delivery_parts: deliveries.length, deliveries_registered_at: at)
        deliveries.each { |delivery| reconcile_registered_delivery!(usage, delivery) }
      end
      resolve_released_allowance!(usage)
      usage
    end

    def reconcile_delivery!(delivery)
      usage = delivery_usage(delivery)
      return unless usage

      usage.with_lock { reconcile_registered_delivery!(usage, delivery) }
      resolve_released_allowance!(usage)
    rescue StandardError => e
      Rails.logger.error("AI reply usage reconciliation failed delivery_id=#{delivery.id} error=#{e.class.name}")
    end

    def reconcile!(usage:, outcome:, platform_app:, reason:)
      return manual_release!(usage, platform_app, reason) if outcome.to_s == 'confirmed_not_sent'

      usage.with_lock do
        return usage if usage.settled? || usage.released?

        apply_manual_outcome!(usage, outcome, platform_app, reason)
        usage
      end
    end

    private

    def deliveries_for(messages)
      message_ids = messages.map(&:id)
      by_message = Whatsapp::OutboundDelivery.where(message_id: message_ids).index_by(&:message_id)
      message_ids.filter_map { |message_id| by_message[message_id] }
    end

    def manual_release!(usage, platform_app, reason)
      sent_evidence = usage.partially_delivered? || confirmed_sent_deliveries(usage).any?
      raise ArgumentError, 'Confirmed sent evidence prevents allowance release' if sent_evidence

      AiLeadEmployee::ReplyAllowance.release!(usage: usage, reason: reason, platform_app: platform_app)
    end

    def delivery_usage(delivery)
      AiLeadEmployee::AiReplyUsage.for_delivery(delivery)
    end

    def reconcile_registered_delivery!(usage, delivery)
      return unless ready_to_reconcile?(usage)

      deliveries = usage.whatsapp_outbound_deliveries.reload
      case reconciliation_outcome(usage, deliveries)
      when :settled then settle_logical_reply!(usage, deliveries)
      when :released then release_logical_reply!(usage, delivery)
      when :partial
        usage.update!(status: :partially_delivered, reconciliation_reason: 'partial_delivery_requires_reconciliation')
      end
    end

    def ready_to_reconcile?(usage)
      (usage.reserved? || usage.partially_delivered?) && usage.deliveries_registered_at.present?
    end

    def reconciliation_outcome(usage, deliveries)
      return :incomplete if deliveries.size < usage.expected_delivery_parts
      return :settled if deliveries.all? { |delivery| confirmed_sent?(delivery) }
      return :indeterminate if usage.partially_delivered?

      terminal_or_indeterminate_outcome(usage, deliveries)
    end

    def terminal_or_indeterminate_outcome(usage, deliveries)
      return indeterminate_outcome(usage, deliveries) if indeterminate?(deliveries)
      return :partial if deliveries.any? { |delivery| confirmed_sent?(delivery) }

      :released
    end

    def indeterminate_outcome(usage, deliveries)
      usage.update!(reconciliation_reason: 'acceptance_unknown') if deliveries.any?(&:unknown?)
      :indeterminate
    end

    def indeterminate?(deliveries)
      deliveries.any? do |delivery|
        delivery.state.in?(%w[pending claimed dispatching unknown]) ||
          (delivery.accepted? && provider_status(delivery).blank?)
      end
    end

    def settle_logical_reply!(usage, deliveries)
      usage.update!(status: :settled, settled_at: deliveries.filter_map { |delivery| provider_receipt_at(delivery) }.max || Time.current,
                    reconciliation_reason: 'canonical_logical_reply_confirmed')
    end

    def release_logical_reply!(usage, delivery)
      usage.update!(status: :released, released_at: Time.current, reconciliation_reason: delivery.failure_code)
    end

    def resolve_released_allowance!(usage)
      return unless usage.released?

      AiLeadEmployee::ReplyAllowance.release!(usage: usage, reason: usage.reconciliation_reason)
    end

    def apply_manual_outcome!(usage, outcome, platform_app, reason)
      attributes = { reconciliation_reason: reason, reconciled_by_platform_app: platform_app }
      case outcome.to_s
      when 'confirmed_sent'
        deliveries = usage.whatsapp_outbound_deliveries.reload
        raise ArgumentError, 'Canonical delivery acceptance is required before settlement' unless canonical_deliveries_confirmed?(usage, deliveries)

        settled_at = deliveries.filter_map { |delivery| provider_receipt_at(delivery) }.max || Time.current
        usage.update!(attributes.merge(status: :settled, settled_at: settled_at))
      else
        raise ArgumentError, 'Outcome must be confirmed_sent or confirmed_not_sent'
      end
    end

    def canonical_deliveries_confirmed?(usage, deliveries)
      usage.deliveries_registered_at.present? && deliveries.size == usage.expected_delivery_parts &&
        deliveries.all? { |delivery| confirmed_sent?(delivery) }
    end

    def confirmed_sent_deliveries(usage)
      usage.whatsapp_outbound_deliveries.reload.select { |delivery| confirmed_sent?(delivery) }
    end

    def confirmed_sent?(delivery)
      delivery.accepted? && provider_status(delivery).in?(CONFIRMED_PROVIDER_STATUSES)
    end

    def provider_status(delivery)
      delivery.message.content_attributes['whatsapp_provider_status']
    end

    def provider_receipt_at(delivery)
      timestamp = delivery.message.content_attributes['whatsapp_delivery_timestamp']
      Time.at(timestamp.to_i).utc if timestamp.present?
    end
  end
end
