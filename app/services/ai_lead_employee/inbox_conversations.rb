class AiLeadEmployee::InboxConversations
  PAGE_SIZE = 25

  def initialize(scope:, user:, filters:)
    @scope = scope
    @user = user
    @filters = filters.to_h.with_indifferent_access
  end

  def perform
    filtered = filtered_scope
    selected = queue_scope(filtered, filters[:queue])
    total = selected.count
    page = filters[:page].to_i.clamp(1, [(total.to_f / PAGE_SIZE).ceil, 1].max)
    {
      conversations: rows(selected, page), total: total, page: page,
      pages: [(total.to_f / PAGE_SIZE).ceil, 1].max,
      counts: %w[all review hot].index_with { |queue| queue_scope(filtered, queue).count },
      filter_options: filter_options
    }
  end

  private

  attr_reader :scope, :user, :filters

  def rows(selected, page)
    conversations = selected.includes(:inbox, :assignee, :human_review_requests, contact: :lead_qualification)
                            .order(last_activity_at: :desc, id: :desc).limit(PAGE_SIZE).offset((page - 1) * PAGE_SIZE).to_a
    previews = latest_public_previews(conversations.map(&:id))
    conversations.map do |conversation|
      AiLeadEmployee::InboxConversationRow.new(conversation, last_message_preview: previews[conversation.id]).to_h
    end
  end

  def latest_public_previews(conversation_ids)
    Message.non_activity_messages.where(conversation_id: conversation_ids, private: false)
           .reorder(:conversation_id, created_at: :desc, id: :desc)
           .pluck(Arel.sql('DISTINCT ON (conversation_id) conversation_id'), :content).to_h
  end

  def filtered_scope
    result = scope.where("COALESCE(conversations.additional_attributes->>'ai_lead_employee_alert_conversation', 'false') != 'true'")
    result = result.where(inbox_id: filters[:source_id]) if filters[:source_id].present?
    result = filter_assignee(result)
    result = filter_qualification(result, :quality)
    result = filter_qualification(result, :follow_up_state)
    filter_search(filter_scheduled_work(result))
  end

  def filter_scheduled_work(result)
    booked = Booking.confirmed.where(conversation_id: scope.select(:id)).select(:conversation_id)
    result = result.where(id: booked) if filters[:booking_status] == 'booked'
    result = result.where.not(id: booked) if filters[:booking_status] == 'not_booked'
    if filters[:follow_up_status] == 'due'
      due = LeadFollowUp.pending.where(conversation_id: scope.select(:id)).where(scheduled_at: ..Time.current)
      result = result.where(id: due.select(:conversation_id))
    end
    result
  end

  def filter_assignee(result)
    return result if filters[:assignee_id].blank?

    assignee = { 'me' => user.id, 'unassigned' => nil }.fetch(filters[:assignee_id], filters[:assignee_id])
    result.where(assignee_id: assignee)
  end

  def filter_qualification(result, field)
    return result if filters[field].blank?

    qualifications = LeadQualification.where(account_id: scope.select(:account_id))
    matches = qualifications.where(field => filters[field]).select(:contact_id)
    filtered = result.where(contact_id: matches)
    return filtered unless (field == :quality && filters[field] == 'unknown') ||
                           (field == :follow_up_state && filters[field] == 'no_follow_up')

    filtered.or(result.where.not(contact_id: qualifications.select(:contact_id)))
  end

  def filter_search(result)
    return result if filters[:q].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(filters[:q].strip)}%"
    contacts = Contact.where(id: result.select(:contact_id)).where(
      'name ILIKE :q OR phone_number ILIKE :q OR email ILIKE :q OR additional_attributes::text ILIKE :q', q: query
    )
    messages = Message.where(conversation_id: result.select(:id), private: false).non_activity_messages.where('content ILIKE ?', query)
    result.where(contact_id: contacts.select(:id)).or(result.where(id: messages.select(:conversation_id)))
  end

  def queue_scope(result, queue)
    case queue
    when 'hot'
      result.where(contact_id: LeadQualification.where(account_id: scope.select(:account_id)).highly_qualified.select(:contact_id))
    when 'review'
      result.where(id: HumanReviewRequest.open.where(conversation_id: scope.select(:id)).select(:conversation_id))
    else
      result
    end
  end

  def filter_options
    {
      qualities: LeadQualification.qualities.keys,
      follow_up_states: LeadQualification.follow_up_states.keys,
      booking_statuses: %w[booked not_booked],
      assignees: User.where(id: scope.select(:assignee_id)).order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      sources: Inbox.where(id: scope.select(:inbox_id)).order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    }
  end
end
