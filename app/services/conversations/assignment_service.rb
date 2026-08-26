class Conversations::AssignmentService
  def initialize(conversation:, assignee_id:, assignee_type: nil)
    @conversation = conversation
    @assignee_id = assignee_id
    @assignee_type = assignee_type
  end

  def perform
    agent_bot_assignment? ? assign_agent_bot : assign_agent
  end

  private

  attr_reader :conversation, :assignee_id, :assignee_type

  def assign_agent
    conversation.with_lock do
      previous_assignee_id = conversation.assignee_id
      open_for_human_assignment if should_open_for_human_assignment?
      apply_human_assignment
      conversation.save!
      audit_human_reassignment!(previous_assignee_id) if previous_assignee_id != conversation.assignee_id
    end
    AiLeadEmployee::FollowUpScheduler.cancel_pending_for!(conversation: conversation, reason: 'control_state_human_active') if assignee.present?
    assignee
  end

  def assign_agent_bot
    return unless agent_bot

    conversation.with_lock do
      conversation.assignee = nil
      conversation.assignee_agent_bot = agent_bot
      conversation.status = :pending
      conversation.control_state = :ai_active
      conversation.control_version += 1
      conversation.save!
    end
    agent_bot
  end

  def assignee
    @assignee ||= conversation.account.users.find_by(id: assignee_id)
  end

  def apply_human_assignment
    conversation.assignee = assignee
    conversation.assignee_agent_bot = nil
    return if assignee.blank?

    conversation.control_state = :human_active
    conversation.control_version += 1
  end

  def open_for_human_assignment
    conversation.status = :open
    conversation.waiting_since = Time.current if conversation.waiting_since.blank?
  end

  def should_open_for_human_assignment?
    assignee.present? && conversation.assignee_agent_bot_id.present? && conversation.pending?
  end

  def agent_bot
    @agent_bot ||= AgentBot.accessible_to(conversation.account).find_by(id: assignee_id)
  end

  def agent_bot_assignment?
    assignee_type.to_s == 'AgentBot'
  end

  def audit_human_reassignment!(previous_assignee_id)
    return unless conversation.persisted?

    Audited::Audit.create!(
      auditable: conversation,
      associated: conversation.account,
      user: Current.user,
      action: 'update',
      audited_changes: { 'assignee_id' => [previous_assignee_id, conversation.assignee_id] },
      version: next_audit_version,
      created_at: Time.current
    )
  end

  def next_audit_version
    Audited::Audit.where(auditable: conversation).maximum(:version).to_i + 1
  end
end
