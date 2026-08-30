# frozen_string_literal: true

class AiLeadEmployee::OperationalDashboardService # rubocop:disable Metrics/ClassLength
  QUEUES = [
    { key: 'all_leads', filters: {} },
    { key: 'hot_leads', filters: { quality: 'highly_qualified' } },
    { key: 'reviews', filters: { review_status: 'open' } },
    { key: 'unanswered_questions', filters: { review_status: 'open' } },
    { key: 'knowledge_approval', filters: { knowledge_approval: 'true' } },
    { key: 'booked_calls', filters: { booking_status: 'booked' } },
    { key: 'follow_up', filters: { follow_up_status: 'pending' } },
    { key: 'unassigned', filters: { assignee_id: 'unassigned' } },
    { key: 'my_queue', filters: { assignee_id: 'me' } },
    { key: 'ai_active', filters: { control_state: 'ai_active' } },
    { key: 'human_active', filters: { control_state: 'human_active' } }
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
      method(:apply_conversation_filter),
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

  def apply_conversation_filter(scope)
    return scope unless conversation_filters?

    scope.where(contact_id: filtered_visible_conversations.select(:contact_id))
  end

  def conversation_filters?
    filters[:assignee_id].present? ||
      filters[:source_id].present? ||
      filters[:review_status].present? ||
      truthy?(filters[:unanswered]) ||
      truthy?(filters[:knowledge_approval]) ||
      filters[:follow_up_status].present? ||
      filters[:control_state].present?
  end

  def filtered_visible_conversations
    @filtered_visible_conversations ||= begin
      scope = visible_conversations
      scope = filter_conversations_by_assignee(scope)
      scope = filter_conversations_by_source(scope)
      scope = filter_conversations_by_review(scope)
      scope = filter_conversations_by_knowledge_approval(scope)
      scope = filter_conversations_by_follow_up_status(scope)
      scope = filter_conversations_by_control_state(scope)
      scope
    end
  end

  def filter_conversations_by_assignee(scope)
    return scope if filters[:assignee_id].blank?

    if filters[:assignee_id] == 'unassigned'
      scope.where(assignee_id: nil)
    elsif filters[:assignee_id] == 'me'
      scope.where(assignee_id: user.id)
    else
      scope.where(assignee_id: filters[:assignee_id])
    end
  end

  def filter_conversations_by_source(scope)
    return scope if filters[:source_id].blank?

    scope.where(inbox_id: filters[:source_id])
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

  def row_conversation_scope
    conversation_filters? ? filtered_visible_conversations : visible_conversations
  end

  def latest_visible_conversation(contact)
    row_conversation_scope
      .where(contact: contact)
      .includes(:assignee, :inbox, :human_review_requests)
      .order(last_activity_at: :desc, id: :desc)
      .first
  end

  def filter_conversations_by_review(scope)
    status = truthy?(filters[:unanswered]) ? 'open' : filters[:review_status]
    return scope if status.blank?

    review_scope = HumanReviewRequest.where(account: account, conversation_id: scope.select(:id))
    review_scope = review_scope.public_send(status) if HumanReviewRequest.statuses.key?(status.to_s)
    scope.where(id: review_scope.select(:conversation_id))
  end

  def filter_conversations_by_knowledge_approval(scope)
    return scope unless truthy?(filters[:knowledge_approval])

    review_conversation_ids = HumanReviewRequest.open
                                                .where(account: account, conversation_id: scope.select(:id))
                                                .where.not(knowledge_item_id: nil)
                                                .select(:conversation_id)
    scope.where(id: review_conversation_ids)
  end

  def filter_conversations_by_follow_up_status(scope)
    return scope if filters[:follow_up_status].blank?

    follow_up_scope = LeadFollowUp.where(account: account, conversation_id: scope.select(:id))
    follow_up_scope = follow_up_scope.public_send(filters[:follow_up_status]) if LeadFollowUp.statuses.key?(filters[:follow_up_status].to_s)
    scope.where(id: follow_up_scope.select(:conversation_id))
  end

  def filter_conversations_by_control_state(scope)
    return scope if filters[:control_state].blank?

    scope.where(control_state: filters[:control_state])
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
      review_statuses: HumanReviewRequest.statuses.keys,
      follow_up_statuses: LeadFollowUp.statuses.keys,
      control_states: Conversation.control_states.keys,
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
