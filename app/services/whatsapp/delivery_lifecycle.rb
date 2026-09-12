# frozen_string_literal: true

# Owns the whole mutation suffix, including batch publication. Authority and
# unknown-review owners acquire their C/O/R prefix before entering this class.
# Never discover a successor from current_follow_up_id for an old Message/job.
class Whatsapp::DeliveryLifecycle
  AssociationChanged = Class.new(StandardError)

  def self.with(deliveries: Whatsapp::OutboundDelivery.none, follow_ups: LeadFollowUp.none)
    ApplicationRecord.transaction do
      owner = new(deliveries: deliveries, follow_ups: follow_ups)
      owner.lock!
      yield owner
    end
  end

  def initialize(deliveries:, follow_ups:)
    @delivery_ids = deliveries.pluck(:id)
    message_ids = Whatsapp::OutboundDelivery.where(id: @delivery_ids).pluck(:message_id)
    @originals = LeadFollowUp.where(id: follow_ups.pluck(:id)).or(LeadFollowUp.where(message_id: message_ids)).order(:id).to_a
    @identities = @originals.to_h { |f| [f.id, [f.follow_up_attempt_id, f.message_id]] }
    @delivery_ids |= Whatsapp::OutboundDelivery.where(message_id: @originals.filter_map(&:message_id)).pluck(:id)
  end

  attr_reader :attempts, :follow_ups, :deliveries

  def lock! # rubocop:disable Metrics/AbcSize
    @attempts = LeadFollowUpAttempt.where(id: @originals.map(&:follow_up_attempt_id)).order(:id).lock('FOR NO KEY UPDATE').index_by(&:id)
    @follow_ups = LeadFollowUp.where(id: @originals.map(&:id)).order(:id).lock('FOR NO KEY UPDATE').index_by(&:id)
    raise AssociationChanged unless follow_ups.all? { |id, f| @identities[id] == [f.follow_up_attempt_id, f.message_id] }

    @deliveries = Whatsapp::OutboundDelivery.where(id: @delivery_ids).order(:id).lock('FOR NO KEY UPDATE').index_by(&:id)
    message_ids = deliveries.values.map(&:message_id) | follow_ups.values.filter_map(&:message_id)
    Message.where(id: message_ids).order(:id).lock('FOR NO KEY UPDATE').load
    OutboxEvent.where(aggregate_type: 'Message', aggregate_id: message_ids).order(:id).lock('FOR NO KEY UPDATE').load
    self
  end

  def artifact_for(delivery)
    follow_ups.values.find { |f| f.message_id == delivery.message_id && f.account_id == delivery.account_id }
  end

  def current?(follow_up)
    attempt = attempts.fetch(follow_up.follow_up_attempt_id)
    attempt.current_follow_up_id == follow_up.id && follow_up.superseded_at.nil?
  end

  def admission_failure(delivery)
    follow_up = artifact_for(delivery)
    if follow_up.nil?
      return 'follow_up_identity_invalid' if delivery.message.additional_attributes.dig('ai_lead_employee', 'follow_up_id')

      return nil
    end
    return 'follow_up_superseded' unless current?(follow_up)
    return 'follow_up_attempt_consumed' unless follow_up.pending? && attempts.fetch(follow_up.follow_up_attempt_id).replaceable?
    return 'qualification_context_invalid' unless delivery.message.additional_attributes.dig('ai_lead_employee', 'qualification_context').to_h ==
                                                  follow_up.qualification_context

    nil
  end

  def admit!(delivery, at:)
    follow_up = artifact_for(delivery)
    return unless follow_up

    attempts.fetch(follow_up.follow_up_attempt_id).update!(admission_state: :admitted, admitted_at: at)
  end

  def outcome!(delivery) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    follow_up = artifact_for(delivery)
    return unless follow_up

    attempt = attempts.fetch(follow_up.follow_up_attempt_id)
    attempt.update!(admitted_at: delivery.dispatch_started_at) if attempt.admitted_at.nil? && delivery.dispatch_started_at.present?
    case delivery.state
    when 'accepted'
      attempt.update!(admission_state: :accepted)
      follow_up.update!(status: :sent, sent_at: delivery.accepted_at) unless follow_up.sent?
    when 'unknown'
      attempt.update!(admission_state: :unknown) unless attempt.accepted?
    when 'failed'
      attempt.update!(admission_state: :failed) unless attempt.accepted?
      follow_up.update!(status: :failed, failed_at: Time.current, failure_reason: delivery.failure_code) if follow_up.pending?
    end
  end

  def cancel_artifact!(follow_up, reason:, delivery_reason: reason) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    attempt = attempts.fetch(follow_up.follow_up_attempt_id)
    return false unless current?(follow_up)
    return false unless attempt.admitted_at.nil? && attempt.admission_state.in?(%w[unadmitted blocked])
    return false unless follow_up.pending? || follow_up.cancelled?

    delivery = deliveries.values.find { |d| d.message_id == follow_up.message_id }
    return false if delivery && (delivery.dispatch_started_at.present? || !delivery.state.in?(%w[pending claimed canceled]))

    contextual = LeadFollowUp::CONTEXT_REPLACEMENT_REASONS.include?(reason) && follow_up.qualification_context.present? && attempt.offer_id.present?
    attempt.update!(admission_state: :blocked) unless contextual || attempt.blocked?
    follow_up.update!(status: :cancelled, cancellation_reason: reason, cancelled_at: Time.current) if follow_up.pending?
    cancel_delivery!(delivery, reason: delivery_reason) if delivery
    true
  end

  def cancel_delivery!(delivery, reason:)
    return false unless delivery.dispatch_started_at.nil? && delivery.state.in?(%w[pending claimed])

    delivery.update!(state: :canceled, failure_code: reason, owner_token: nil, lease_expires_at: nil)
    delivery.publish!
    true
  end

  def cancel!(delivery, reason:)
    follow_up = artifact_for(delivery)
    follow_up ? cancel_artifact!(follow_up, reason: reason) : cancel_delivery!(delivery, reason: reason)
  end
end
