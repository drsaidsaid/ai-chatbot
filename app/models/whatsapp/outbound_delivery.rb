class Whatsapp::OutboundDelivery < ApplicationRecord
  self.table_name = 'whatsapp_outbound_deliveries'
  belongs_to :account
  belongs_to :conversation
  belongs_to :message

  enum :state, %w[pending claimed dispatching accepted unknown failed canceled].index_with(&:itself)

  MAX_CLAIM_ATTEMPTS = 3

  scope :recoverable, lambda {
    where(state: 'pending').or(where(state: %w[claimed dispatching]).where('lease_expires_at IS NULL OR lease_expires_at <= ?', Time.current))
  }

  def recover!
    with_lifecycle(review: true) do |owner, reviews|
      next false if cancel_inadmissible_recovery!(owner)

      if pending?
        update!(updated_at: Time.current)
        next true
      end
      next false if lease_expires_at&.future?

      if dispatching?
        record_unknown_locked!(owner, reviews)
      elsif claimed?
        next recover_claim!(owner)
      end
      false
    end
  end

  def record_unknown!
    with_lifecycle(review: true) { |owner, reviews| record_unknown_locked!(owner, reviews) if dispatching? }
  end

  def fail_preparation!(owner: nil)
    with_lifecycle do |lifecycle, _reviews|
      next false unless owner ? claimed? && owner_token == owner : pending?

      update!(state: :failed, failure_code: 'preparation_failed')
      lifecycle.outcome!(self)
      message.update!(status: :failed, external_error: 'This reply could not be prepared. Review its content or template before retrying.')
      publish!
      true
    end
  end

  def retry_for?(user)
    ApplicationRecord.transaction do
      Conversation.where(id: conversation_id).lock('FOR NO KEY UPDATE').load
      conversation.reload
      AiLeadEmployee::OfferDeliveryContext.new(conversation: conversation,
                                               context: message.additional_attributes.dig('ai_lead_employee',
                                                                                          'qualification_context')).lock_offers!
      next false unless retry_authorized?(user)

      with_lifecycle do |lifecycle, _reviews|
        retry_locked!(lifecycle)
      end
    end
  end

  def self.cancel_automation!(conversation:, reason:)
    AiLeadEmployee::AutomationCancellation.call(conversation: conversation, reason: reason)
  end

  def reconcile!
    with_lifecycle do |owner, _reviews|
      owner.outcome!(self)
      publish!
    end
  end

  # Unknown review absence is serialized by C; existing R is acquired before A/F.
  # The suffix helper never discovers an earlier authority during publication.
  def with_lifecycle(review: false)
    ApplicationRecord.transaction do
      reviews = []
      if review
        Conversation.where(account_id: account_id, id: conversation_id).order(:id).lock('FOR NO KEY UPDATE').load
        conversation.reload
        reviews = HumanReviewRequest.where(account_id: account_id, conversation_id: conversation_id,
                                           lead_message_id: message_id, reason: :delivery_unknown).order(:id).lock.to_a
      end
      Whatsapp::DeliveryLifecycle.with(deliveries: self.class.where(id: id)) do |owner|
        reload
        yield owner, reviews
      end
    end
  end

  def record_unknown_locked!(owner, reviews)
    update!(state: :unknown, failure_code: 'acceptance_unknown')
    owner.outcome!(self)
    if reviews.empty?
      HumanReviewRequest.create!(account: account, conversation: conversation, lead_message: message, reason: :delivery_unknown,
                                 question: "Delivery outcome unknown for message #{message_id}. " \
                                           'Check the provider outcome before contacting the Lead again.',
                                 assigned_user_id: conversation.assignee_id)
    end
    publish!
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

  def cancel_inadmissible_recovery!(owner)
    return false unless pending? || claimed?

    reason = owner.admission_failure(self)
    return false unless reason

    owner.cancel!(self, reason: reason)
    true
  end

  def retry_authorized?(user)
    membership = AccountUser.where(account_id: account_id, user_id: user&.id).lock.first
    account.reload.active? && membership && (membership.administrator? || conversation.assignee_id == user.id)
  end

  def retry_locked!(lifecycle)
    return false if lifecycle.artifact_for(self)
    return false unless failed? && message.reload.source_id.blank?

    update!(state: :pending, owner_token: nil, lease_expires_at: nil, failure_code: nil)
    message.update!(status: :sent, external_error: nil)
    publish!
    true
  end

  def recover_claim!(owner)
    if attempts >= MAX_CLAIM_ATTEMPTS
      update!(state: :failed, failure_code: 'claim_recovery_exhausted')
      owner.outcome!(self)
      message.update!(status: :failed, external_error: 'Delivery could not start. Review the connection before retrying.')
      publish!
      false
    else
      update!(state: :pending, owner_token: nil, lease_expires_at: nil)
      true
    end
  end

  def outbox_state
    return 'delivered' if accepted?

    state.in?(%w[failed canceled unknown]) ? state : 'pending'
  end

  def publish_outbox!
    event_state = outbox_state
    OutboxEvent.where(account_id: account_id, aggregate_type: 'Message', aggregate_id: message_id).find_each do |event|
      event.update!(state: event_state, attempts: attempts, delivered_at: accepted_at,
                    failure_class: failure_code, failed_at: failure_code ? Time.current : nil)
    end
  end
end
