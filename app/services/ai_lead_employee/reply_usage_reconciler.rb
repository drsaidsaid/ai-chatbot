# frozen_string_literal: true

class AiLeadEmployee::ReplyUsageReconciler
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
        return usage unless usage.reserved?

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
      AiLeadEmployee::ReplyAllowance.release!(usage: usage, reason: reason, platform_app: platform_app)
    end

    def delivery_usage(delivery)
      return delivery.ai_reply_usage if delivery.ai_reply_usage

      usage_id = delivery.message.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')
      AiLeadEmployee::AiReplyUsage.find_by(id: usage_id, account_id: delivery.account_id)
    end

    def reconcile_registered_delivery!(usage, delivery)
      return unless ready_to_reconcile?(usage)

      deliveries = usage.whatsapp_outbound_deliveries.reload
      case reconciliation_outcome(usage, deliveries)
      when :settled then settle_logical_reply!(usage, deliveries)
      when :released then release_logical_reply!(usage, delivery)
      when :partial then usage.update!(reconciliation_reason: 'partial_delivery_requires_reconciliation')
      end
    end

    def ready_to_reconcile?(usage)
      usage.reserved? && usage.deliveries_registered_at.present?
    end

    def reconciliation_outcome(usage, deliveries)
      return :incomplete if deliveries.size < usage.expected_delivery_parts
      return :settled if deliveries.all?(&:accepted?)
      return :indeterminate if indeterminate?(deliveries)
      return :released unless deliveries.any?(&:accepted?)

      :partial
    end

    def indeterminate?(deliveries)
      deliveries.any? { |item| item.state.in?(%w[pending claimed dispatching unknown]) }
    end

    def settle_logical_reply!(usage, deliveries)
      usage.update!(status: :settled, settled_at: deliveries.filter_map(&:accepted_at).max || Time.current,
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
        usage.update!(attributes.merge(status: :settled, settled_at: Time.current))
      else
        raise ArgumentError, 'Outcome must be confirmed_sent or confirmed_not_sent'
      end
    end
  end
end
