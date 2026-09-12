class Whatsapp::OutboundDelivery < ApplicationRecord
  self.table_name = 'whatsapp_outbound_deliveries'
  belongs_to :account
  belongs_to :conversation
  belongs_to :message
  belongs_to :ai_reply_usage, class_name: 'AiLeadEmployee::AiReplyUsage', optional: true

  enum :state, %w[pending claimed dispatching accepted unknown failed canceled].index_with(&:itself)

  after_update_commit :reconcile_ai_reply_usage, if: :saved_change_to_state?

  validate :tenant_scope

  MAX_CLAIM_ATTEMPTS = 3

  scope :recoverable, lambda {
    where(state: 'pending').or(where(state: %w[claimed dispatching]).where('lease_expires_at IS NULL OR lease_expires_at <= ?', Time.current))
  }
  scope :retryable_subscription_alerts, lambda {
    joins(:message).where(state: 'failed', attempts: ...MAX_CLAIM_ATTEMPTS)
                   .where("messages.additional_attributes #>> '{ai_lead_employee,alert_type}' = ?",
                          AiLeadEmployee::SubscriptionAlertDeliveryService::ALERT_TYPE)
  }

  private

  def tenant_scope
    return if account_id.blank?

    validate_association_account(:conversation, conversation)
    validate_association_account(:message, message)
    validate_association_account(:ai_reply_usage, ai_reply_usage) if ai_reply_usage
  end

  def validate_association_account(name, record)
    errors.add(name, 'must belong to the same Business Account') if record&.account_id != account_id
  end

  public

  def recover!
    conversation.with_lock do
      lock!
      if pending?
        update!(updated_at: Time.current) # A queue outage must not starve later rows.
        return true
      end
      return false if lease_expires_at&.future?

      if dispatching?
        record_unknown!
      elsif claimed?
        return recover_claim!
      end
      false
    end
  end

  def record_unknown!
    update!(state: :unknown, failure_code: 'acceptance_unknown')
    publish!
    HumanReviewRequest.find_or_create_by!(account: account, conversation: conversation, lead_message: message, reason: :delivery_unknown) do |review|
      review.question = "Delivery outcome unknown for message #{message_id}. Check the provider outcome before contacting the Lead again."
      review.assigned_user_id = conversation.assignee_id
    end
  end

  def fail_preparation!(owner: nil)
    with_lock do
      return false unless owner ? claimed? && owner_token == owner : pending?

      update!(state: :failed, failure_code: 'preparation_failed')
      message.update!(status: :failed, external_error: 'This reply could not be prepared. Review its content or template before retrying.')
      publish!
      true
    end
  end

  def retry_for?(user)
    conversation.with_lock do
      lock!
      return false unless operator_allowed?(user)
      return false unless failed? && message.reload.source_id.blank?
      return false unless AiLeadEmployee::ReplyAllowance.rereserve_for_delivery!(self)

      update!(state: :pending, owner_token: nil, lease_expires_at: nil, failure_code: nil)
      message.update!(status: :sent, external_error: nil)
      publish!
      true
    end
  end

  def retry_subscription_alert!
    with_lock do
      return false unless state.in?(%w[failed canceled]) && message.reload.source_id.blank?
      return false unless message.additional_attributes.dig('ai_lead_employee', 'alert_type') ==
                          AiLeadEmployee::SubscriptionAlertDeliveryService::ALERT_TYPE

      authority_failure = Whatsapp::OutboundAlertAuthority.new(message).failure_code
      if authority_failure
        update!(state: :canceled, failure_code: authority_failure)
        publish!
        return false
      end

      update!(state: :pending, owner_token: nil, lease_expires_at: nil, failure_code: nil)
      message.update!(status: :sent, external_error: nil)
      publish!
      true
    end
  end

  def self.cancel_automation!(conversation:, reason:)
    joins(:message).where(account_id: conversation.account_id, state: %w[pending claimed])
                   .where('whatsapp_outbound_deliveries.conversation_id = :id OR ' \
                          "messages.additional_attributes #>> '{ai_lead_employee,origin_conversation_id}' = :text_id",
                          id: conversation.id, text_id: conversation.id.to_s)
                   .where("messages.sender_type IS NULL OR messages.sender_type != 'User'").find_each do |delivery|
      delivery.with_lock do
        next unless delivery.pending? || delivery.claimed?

        delivery.update!(state: :canceled, failure_code: reason)
        delivery.publish!
      end
    end
  end

  def publish!
    message.with_lock do
      message.update!(content_attributes: message.content_attributes.merge(
        'whatsapp_delivery' => { 'state' => state, 'failure_code' => failure_code }
      ))
    end
    publish_outbox!
  end

  private

  def reconcile_ai_reply_usage
    AiLeadEmployee::ReplyAllowance.reconcile_delivery!(self)
  end

  def recover_claim!
    if attempts >= MAX_CLAIM_ATTEMPTS
      update!(state: :failed, failure_code: 'claim_recovery_exhausted')
      message.update!(status: :failed, external_error: 'Delivery could not start. Review the connection before retrying.')
      publish!
      false
    else
      update!(state: :pending, owner_token: nil, lease_expires_at: nil)
      true
    end
  end

  def operator_allowed?(user)
    membership = AccountUser.lock.find_by(account_id: account_id, user_id: user&.id)
    account.reload.active? && membership && (membership.administrator? || conversation.assignee_id == user.id)
  end

  def outbox_state
    return 'delivered' if accepted?

    state.in?(%w[failed canceled unknown]) ? state : 'pending'
  end

  def mark_follow_up_sent!(event)
    return unless event.payload['follow_up_id']

    follow_up = LeadFollowUp.find_by(account_id: account_id, id: event.payload['follow_up_id'])
    follow_up.update!(status: :sent, sent_at: accepted_at) if follow_up&.pending?
  end

  def publish_outbox!
    event_state = outbox_state
    OutboxEvent.where(account_id: account_id, aggregate_type: 'Message', aggregate_id: message_id).find_each do |event|
      event.update!(state: event_state, attempts: attempts, delivered_at: accepted_at,
                    failure_class: failure_code, failed_at: failure_code ? Time.current : nil)
      mark_follow_up_sent!(event) if accepted?
    end
  end
end
