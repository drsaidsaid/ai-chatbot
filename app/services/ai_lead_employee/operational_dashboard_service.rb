# frozen_string_literal: true

class AiLeadEmployee::OperationalDashboardService
  QUEUES = [
    { key: 'all_leads', filters: {} },
    { key: 'hot_leads', filters: { quality: 'highly_qualified' } },
    { key: 'unanswered_questions', filters: { unanswered: 'true' } },
    { key: 'knowledge_approval', filters: { knowledge_approval: 'true' } },
    { key: 'booked_calls', filters: { booking_status: 'booked' } },
    { key: 'my_queue', filters: { assignee_id: 'me' } }
  ].freeze

  def initialize(account:, user:, filters:)
    @account = account
    @user = user
    @filters = filters.to_h.with_indifferent_access
  end

  def perform
    {
      leads: lead_rows,
      performance: performance,
      queues: QUEUES,
      filter_options: filter_options,
      visibility: administrator? ? :admin : :operator
    }
  end

  private

  attr_reader :account, :user, :filters

  def lead_rows
    filtered_qualifications.map { |qualification| row_for(qualification) }
  end

  def filtered_qualifications
    apply_filters(base_qualification_scope).limit(100)
  end

  def row_for(qualification)
    contact = qualification.contact
    conversation = latest_visible_conversation(contact)
    open_reviews = conversation&.human_review_requests&.select(&:open?) || []

    AiLeadEmployee::OperationalDashboardRow.new(
      qualification: qualification,
      conversation: conversation,
      open_reviews: open_reviews
    ).to_h
  end

  def base_qualification_scope
    LeadQualification
      .where(account: account, contact_id: visible_contact_ids)
      .includes(contact: { conversations: [:assignee, :inbox, :human_review_requests] })
      .order(last_evaluated_at: :desc, id: :desc)
  end

  def apply_filters(scope)
    [
      method(:apply_quality_filter),
      method(:apply_follow_up_filter),
      method(:apply_assignee_filter),
      method(:apply_source_filter),
      method(:apply_unanswered_filter),
      method(:apply_knowledge_approval_filter),
      method(:apply_booking_filter)
    ].reduce(scope) { |filtered_scope, filter| filter.call(filtered_scope) }
  end

  def apply_quality_filter(scope)
    return scope if filters[:quality].blank?

    scope.where(quality: filters[:quality])
  end

  def apply_follow_up_filter(scope)
    return scope if filters[:follow_up_state].blank?

    scope.where(follow_up_state: filters[:follow_up_state])
  end

  def apply_assignee_filter(scope)
    return scope if filters[:assignee_id].blank?

    scope.where(contact_id: contacts_for_assignee(filters[:assignee_id]))
  end

  def apply_source_filter(scope)
    return scope if filters[:source_id].blank?

    scope.where(contact_id: contacts_for_source(filters[:source_id]))
  end

  def apply_unanswered_filter(scope)
    return scope unless truthy?(filters[:unanswered])

    scope.where(contact_id: contacts_with_open_reviews)
  end

  def apply_knowledge_approval_filter(scope)
    return scope unless truthy?(filters[:knowledge_approval])

    scope.where(contact_id: contacts_with_knowledge_approval)
  end

  def visible_contact_ids
    visible_conversations.select(:contact_id)
  end

  def visible_conversations
    scope = account.conversations
    return scope if administrator?

    inbox_ids = user.inboxes.where(account: account).select(:id)
    team_ids = user.teams.where(account: account).select(:id)
    scope.where(assignee_id: user.id)
         .or(scope.where(inbox_id: inbox_ids))
         .or(scope.where(team_id: team_ids))
  end

  def latest_visible_conversation(contact)
    visible_conversations
      .where(contact: contact)
      .includes(:assignee, :inbox, :human_review_requests)
      .order(last_activity_at: :desc, id: :desc)
      .first
  end

  def contacts_for_assignee(assignee_id)
    return visible_conversations.where(assignee_id: nil).select(:contact_id) if assignee_id == 'unassigned'
    return visible_conversations.where(assignee_id: user.id).select(:contact_id) if assignee_id == 'me'

    visible_conversations.where(assignee_id: assignee_id).select(:contact_id)
  end

  def contacts_for_source(source_id)
    visible_conversations.where(inbox_id: source_id).select(:contact_id)
  end

  def contacts_with_open_reviews
    review_conversation_ids = HumanReviewRequest.open
                                                .where(account: account, conversation_id: visible_conversations.select(:id))
                                                .select(:conversation_id)
    visible_conversations.where(id: review_conversation_ids).select(:contact_id)
  end

  def contacts_with_knowledge_approval
    review_conversation_ids = HumanReviewRequest.open
                                                .where(account: account, conversation_id: visible_conversations.select(:id))
                                                .where.not(knowledge_item_id: nil)
                                                .select(:conversation_id)
    visible_conversations.where(id: review_conversation_ids).select(:contact_id)
  end

  def apply_booking_filter(scope)
    case filters[:booking_status]
    when 'booked'
      scope.call_booked
    when 'not_booked'
      scope.where.not(follow_up_state: LeadQualification.follow_up_states[:call_booked])
    else
      scope
    end
  end

  def performance
    visible_scope = LeadQualification.where(account: account, contact_id: visible_contact_ids)
    visible_review_scope = HumanReviewRequest.open.where(account: account, conversation_id: visible_conversations.select(:id))

    {
      total_leads: visible_scope.count,
      highly_qualified_leads: visible_scope.highly_qualified.count,
      unanswered_questions: visible_review_scope.count,
      booked_calls: visible_scope.call_booked.count,
      knowledge_approvals: account.knowledge_items.draft.count,
      human_active_conversations: visible_conversations.human_active.count,
      ai_active_conversations: visible_conversations.ai_active.count
    }
  end

  def filter_options
    {
      qualities: LeadQualification.qualities.keys,
      follow_up_states: LeadQualification.follow_up_states.keys,
      booking_statuses: %w[booked not_booked],
      assignees: visible_conversations.includes(:assignee).filter_map { |conversation| user_payload(conversation.assignee) }.uniq,
      sources: visible_conversations.includes(:inbox).filter_map { |conversation| source_payload(conversation.inbox) }.uniq
    }
  end

  def user_payload(assignee)
    return if assignee.blank?

    { id: assignee.id, name: assignee.name, email: assignee.email }
  end

  def source_payload(inbox)
    return if inbox.blank?

    { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
  end

  def administrator?
    account.account_users.find_by(user: user)&.administrator?
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
