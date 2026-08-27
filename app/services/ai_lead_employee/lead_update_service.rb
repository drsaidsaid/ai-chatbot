# frozen_string_literal: true

class AiLeadEmployee::LeadUpdateService
  EDITABLE_EVIDENCE_SIGNALS = QualificationQuestion::SIGNALS.keys.freeze

  def initialize(account:, user:, contact:, attributes:, conversation_scope: nil)
    @account = account
    @user = user
    @contact = contact
    @attributes = attributes.to_h.with_indifferent_access
    @conversation_scope = conversation_scope
    @changed_fields = {}
    @changed_evidence_signals = []
  end

  def perform
    ActiveRecord::Base.transaction do
      update_contact!
      update_assignee!
      record_evidence!
      recompute_qualification!
      audit_update!
    end

    contact
  end

  private

  attr_reader :account, :user, :contact, :attributes, :conversation_scope, :changed_fields, :changed_evidence_signals

  def update_contact!
    validate_required_fields!
    contact.assign_attributes(contact_attributes)
    contact.additional_attributes = merged_additional_attributes
    capture_contact_changes
    contact.save!
  end

  def validate_required_fields!
    return unless attributes.key?(:name) && attributes[:name].blank?

    contact.errors.add(:name, "can't be blank")
    raise ActiveRecord::RecordInvalid, contact
  end

  def contact_attributes
    attributes.slice(:name, :phone_number, :email).compact
  end

  def merged_additional_attributes
    additional = contact.additional_attributes || {}
    {
      'company_name' => attributes[:business_name],
      'city' => attributes[:city],
      'country' => attributes[:country]
    }.compact.each_with_object(additional.dup) do |(key, value), result|
      result[key] = value
    end
  end

  def capture_contact_changes
    tracked_changes = contact.changes.slice('name', 'phone_number', 'email', 'additional_attributes')
    changed_fields.merge!(tracked_changes)
  end

  def update_assignee!
    return unless attributes.key?(:assignee_id)
    return if latest_conversation.blank?

    previous_assignee_id = latest_conversation.assignee_id
    Conversations::AssignmentService.new(
      conversation: latest_conversation,
      assignee_id: attributes[:assignee_id].presence
    ).perform
    return if previous_assignee_id == latest_conversation.reload.assignee_id

    changed_fields['assignee_id'] = [previous_assignee_id, latest_conversation.assignee_id]
  end

  def record_evidence!
    evidence_attributes.each do |signal, value|
      next if value.blank?

      AiLeadEmployee::QualificationService.record_human_evidence!(
        contact: contact,
        conversation: latest_conversation,
        user: user,
        signal: signal,
        value: value
      )
      changed_evidence_signals << signal
    end
  end

  def evidence_attributes
    attributes.fetch(:evidence, {}).to_h.with_indifferent_access.slice(*EDITABLE_EVIDENCE_SIGNALS)
  end

  def recompute_qualification!
    return if changed_evidence_signals.blank? || latest_conversation.blank?

    AiLeadEmployee::QualificationService.new(conversation: latest_conversation).perform
  end

  def audit_update!
    return if changed_fields.blank? && changed_evidence_signals.blank?

    Audited::Audit.create!(
      auditable: contact,
      associated: account,
      user: user,
      action: 'update',
      audited_changes: changed_fields.merge(
        'ai_lead_employee_action' => 'lead_edit',
        'evidence_signals' => changed_evidence_signals
      ),
      version: next_audit_version,
      created_at: Time.current
    )
  end

  def latest_conversation
    @latest_conversation ||= (conversation_scope || account.conversations)
                             .where(contact: contact)
                             .order(last_activity_at: :desc, id: :desc)
                             .first
  end

  def next_audit_version
    Audited::Audit.where(auditable: contact).maximum(:version).to_i + 1
  end
end
