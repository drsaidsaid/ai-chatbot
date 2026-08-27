# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class AiLeadEmployee::LeadsDirectoryService
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  QUALITY_KEYS = %w[all highly_qualified qualified low_qualified unqualified unknown].freeze
  SORT_COLUMNS = %w[name business quality score last_contact].freeze
  DEFAULT_NEXT_ACTION = { key: 'capture_missing_signals', due_at: nil, state: 'qualification' }.freeze
  FOLLOW_UP_NEXT_ACTIONS = {
    'human_review' => { key: 'human_review', due_at: nil, state: 'review' },
    'nurture' => { key: 'send_proposal', due_at: nil, state: 'proposal' },
    'call_booked' => { key: 'book_demo', due_at: nil, state: 'booked' },
    'closed' => { key: 'closed', due_at: nil, state: 'closed' }
  }.freeze

  def initialize(account:, user:, params:)
    @account = account
    @user = user
    @params = params.to_h.with_indifferent_access
  end

  def perform
    page_scope = filtered_scope
    page = paginated_scope(page_scope)
    contacts = page.to_a

    {
      leads: rows_for(contacts),
      selected_lead: selected_lead_payload(contacts),
      counts: quality_counts,
      filter_options: filter_options,
      meta: pagination_payload(page_scope, page)
    }
  end

  def export_rows
    rows_for(filtered_scope.limit(1000).to_a)
  end

  private

  attr_reader :account, :user, :params

  def base_contact_scope
    scope = if administrator?
              account.contacts.resolved_contacts(use_crm_v2: account.feature_enabled?('crm_v2'))
            else
              account.contacts.where(id: visible_contact_ids)
            end
    scope.includes(:lead_qualification).distinct
  end

  def filtered_scope
    apply_sort(apply_filters(base_contact_scope))
  end

  def count_scope
    apply_filters(base_contact_scope, except: [:quality])
  end

  def apply_filters(scope, except: [])
    [
      [:search, method(:apply_search_filter)],
      [:quality, method(:apply_quality_filter)],
      [:follow_up_state, method(:apply_follow_up_filter)],
      [:assignee_id, method(:apply_assignee_filter)],
      [:source_id, method(:apply_source_filter)],
      [:booking_status, method(:apply_booking_filter)]
    ].reduce(scope) do |filtered_scope, (key, filter)|
      except.include?(key) ? filtered_scope : filter.call(filtered_scope)
    end
  end

  def apply_search_filter(scope)
    return scope if params[:q].blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
    message_contact_ids = visible_conversations
                          .joins(:messages)
                          .where('messages.content ILIKE ?', term)
                          .select(:contact_id)

    scope.where(
      <<~SQL.squish,
        contacts.name ILIKE :term
          OR contacts.phone_number ILIKE :term
          OR contacts.email ILIKE :term
          OR contacts.identifier ILIKE :term
          OR contacts.additional_attributes->>'company_name' ILIKE :term
          OR contacts.additional_attributes->>'business_name' ILIKE :term
          OR contacts.id IN (#{message_contact_ids.to_sql})
      SQL
      term: term
    )
  end

  def apply_quality_filter(scope)
    quality = params[:quality].to_s
    return scope if quality.blank? || quality == 'all'
    return unknown_quality_scope(scope) if quality == 'unknown'
    return scope unless LeadQualification.qualities.key?(quality)

    scope.joins(:lead_qualification).where(lead_qualifications: { quality: LeadQualification.qualities[quality] })
  end

  def unknown_quality_scope(scope)
    scope.left_joins(:lead_qualification).where(
      'lead_qualifications.id IS NULL OR lead_qualifications.quality = ?',
      LeadQualification.qualities['unknown']
    )
  end

  def apply_follow_up_filter(scope)
    follow_up_state = params[:follow_up_state].to_s
    return scope if follow_up_state.blank? || LeadQualification.follow_up_states.exclude?(follow_up_state)

    scope.joins(:lead_qualification).where(lead_qualifications: { follow_up_state: LeadQualification.follow_up_states[follow_up_state] })
  end

  def apply_assignee_filter(scope)
    assignee_id = params[:assignee_id].to_s
    return scope if assignee_id.blank?

    scope.where(id: contacts_for_assignee(assignee_id))
  end

  def apply_source_filter(scope)
    source_id = params[:source_id].to_s
    return scope if source_id.blank?

    scope.where(id: visible_conversations.where(inbox_id: source_id).select(:contact_id))
  end

  def apply_booking_filter(scope)
    case params[:booking_status].to_s
    when 'booked'
      scope.where(id: booked_contact_ids)
    when 'no_booking'
      scope.where.not(id: booked_contact_ids)
    when 'canceled', 'completed'
      scope.where(id: Booking.where(account: account, status: params[:booking_status]).select(:contact_id))
    else
      scope
    end
  end

  def apply_sort(scope)
    sort = SORT_COLUMNS.include?(params[:sort].to_s) ? params[:sort].to_s : 'last_contact'
    direction = params[:direction].to_s.downcase == 'asc' ? 'ASC' : 'DESC'

    case sort
    when 'name'
      scope.order(Arel.sql("LOWER(contacts.name) #{direction} NULLS LAST"), id: :asc)
    when 'business'
      scope.order(Arel.sql("LOWER(contacts.additional_attributes->>'company_name') #{direction} NULLS LAST"), id: :asc)
    when 'quality'
      scope.left_joins(:lead_qualification).order(Arel.sql("lead_qualifications.quality #{direction} NULLS LAST"), id: :asc)
    when 'score'
      scope.left_joins(:lead_qualification).order(Arel.sql("lead_qualifications.score #{direction} NULLS LAST"), id: :asc)
    else
      scope.order(Arel.sql("contacts.last_activity_at #{direction} NULLS LAST"), id: :desc)
    end
  end

  def paginated_scope(scope)
    scope.page(current_page).per(per_page)
  end

  def rows_for(contacts)
    preload_context_for(contacts)
    contacts.map { |contact| lead_payload(contact) }
  end

  def lead_payload(contact)
    context = lead_context_for(contact)

    row_payload(contact, context).merge(
      detail: detail_payload(contact, context)
    )
  end

  def lead_context_for(contact)
    {
      qualification: contact.lead_qualification,
      conversation: latest_conversation_for(contact),
      booking: latest_booking_for(contact),
      follow_up: next_follow_up_for(contact),
      evidence: current_evidence_for(contact)
    }
  end

  def row_payload(contact, context)
    contact_identity_payload(contact).merge(
      qualification_row_payload(context),
      workflow_row_payload(contact, context)
    )
  end

  def contact_identity_payload(contact)
    {
      id: contact.id,
      name: contact.name,
      initials: initials_for(contact.name),
      phone_number: contact.phone_number,
      email: contact.email,
      business_name: business_name_for(contact),
      location: location_for(contact)
    }
  end

  def qualification_row_payload(context)
    {
      quality: context[:qualification]&.quality || 'unknown',
      score: context[:qualification]&.score || 0
    }
  end

  def workflow_row_payload(contact, context)
    {
      source: source_payload(context[:conversation]&.inbox),
      assignee: user_payload(context[:conversation]&.assignee),
      last_contact_at: context[:conversation]&.last_activity_at || contact.last_activity_at,
      next_action: next_action_payload(context[:qualification], context[:booking], context[:follow_up]),
      booking: booking_payload(context[:booking], context[:qualification]),
      conversation: conversation_payload(context[:conversation])
    }
  end

  def detail_payload(contact, context)
    {
      contact_channels: contact_channels_for(contact, context[:conversation]),
      qualification: qualification_detail_payload(context[:qualification]),
      why_this_lead_matters: why_this_lead_matters(context[:qualification]),
      strongest_evidence: context[:evidence].first(4).map { |item| evidence_payload(item) },
      missing_signals: context[:qualification]&.missing_signals || [],
      conversation_summary: conversation_summary_payload(context[:conversation]),
      owner_follow_up: owner_follow_up_payload(context),
      related_conversations: related_conversations_for(contact),
      related_bookings: related_bookings_for(contact),
      editable_fields: editable_fields_for(contact, context)
    }
  end

  def qualification_detail_payload(qualification)
    {
      quality: qualification&.quality || 'unknown',
      score: qualification&.score || 0,
      reasons: qualification&.reasons || [],
      follow_up_state: qualification&.follow_up_state || 'no_follow_up',
      last_evaluated_at: qualification&.last_evaluated_at
    }
  end

  def why_this_lead_matters(qualification)
    reasons = qualification&.reasons || []
    return reasons.first(2) if reasons.present?

    ['No qualification reasons captured yet.']
  end

  def evidence_payload(evidence)
    {
      id: evidence.id,
      signal: evidence.signal,
      value: evidence.value&.fetch('value', nil),
      source: evidence.source,
      observed_at: evidence.observed_at
    }
  end

  def conversation_summary_payload(conversation)
    return {} if conversation.blank?

    {
      last_message_at: conversation.last_activity_at,
      last_message_preview: latest_message_for(conversation)&.content,
      first_message_at: first_message_for(conversation)&.created_at,
      total_messages: message_counts[conversation.id] || 0
    }
  end

  def owner_follow_up_payload(context)
    {
      assignee: user_payload(context[:conversation]&.assignee),
      follow_up_state: context[:qualification]&.follow_up_state || 'no_follow_up',
      next_action: next_action_payload(context[:qualification], context[:booking], context[:follow_up])
    }
  end

  def next_action_payload(qualification, booking, follow_up)
    return { key: 'prepare_booked_demo', due_at: booking.starts_at, state: 'booked' } if booking.present? && booking.confirmed?
    return { key: 'follow_up', due_at: follow_up.scheduled_at, state: 'scheduled' } if follow_up.present?

    FOLLOW_UP_NEXT_ACTIONS.fetch(qualification&.follow_up_state, DEFAULT_NEXT_ACTION)
  end

  def booking_payload(booking, qualification)
    return { status: 'no_booking', key: 'no_booking' } if booking.blank? && !qualification&.call_booked?
    return { status: 'booked', key: 'demo' } if booking.blank?

    {
      id: booking.id,
      status: booking.status,
      key: booking.confirmed? ? 'demo' : booking.status,
      starts_at: booking.starts_at,
      ends_at: booking.ends_at,
      path: "/app/accounts/#{account.id}/bookings?booking_id=#{booking.id}",
      assignee: user_payload(booking.assignee)
    }
  end

  def conversation_payload(conversation)
    return {} if conversation.blank?

    {
      id: conversation.id,
      display_id: conversation.display_id,
      status: conversation.status,
      control_state: conversation.control_state,
      path: "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    }
  end

  def contact_channels_for(contact, conversation)
    [
      ({ kind: 'phone', label: contact.phone_number } if contact.phone_number.present?),
      ({ kind: 'email', label: contact.email } if contact.email.present?),
      ({ kind: 'source', label: conversation&.inbox&.name } if conversation&.inbox.present?)
    ].compact
  end

  def related_conversations_for(contact)
    conversations_for_contact(contact).first(5).map do |conversation|
      conversation_payload(conversation).merge(
        source: source_payload(conversation.inbox),
        last_contact_at: conversation.last_activity_at
      )
    end
  end

  def related_bookings_for(contact)
    bookings_for_contact(contact).first(5).map { |booking| booking_payload(booking, contact.lead_qualification) }
  end

  def editable_fields_for(contact, context)
    {
      name: contact.name,
      phone_number: contact.phone_number,
      email: contact.email,
      business_name: business_name_for(contact),
      city: contact.additional_attributes&.dig('city'),
      country: contact.additional_attributes&.dig('country'),
      assignee_id: context[:conversation]&.assignee_id,
      evidence: evidence_snapshot_for(context[:qualification])
    }
  end

  def evidence_snapshot_for(qualification)
    qualification&.evidence_snapshot&.transform_values { |item| item['value'] } || {}
  end

  def selected_lead_payload(contacts)
    selected_id = params[:lead_id].presence || contacts.first&.id
    return if selected_id.blank?

    selected_contact = contacts.find { |contact| contact.id.to_s == selected_id.to_s } ||
                       base_contact_scope.where(id: selected_id).first
    return if selected_contact.blank?

    rows_for([selected_contact]).first
  end

  def pagination_payload(scope, page)
    {
      page: current_page,
      per_page: per_page,
      total_count: scope.count,
      total_pages: page.total_pages,
      sort: SORT_COLUMNS.include?(params[:sort].to_s) ? params[:sort].to_s : 'last_contact',
      direction: params[:direction].to_s.downcase == 'asc' ? 'asc' : 'desc',
      visibility: administrator? ? 'admin' : 'operator'
    }
  end

  def quality_counts
    scope = count_scope
    counts = QUALITY_KEYS.index_with { 0 }
    counts['all'] = scope.count

    LeadQualification.qualities.each_key do |quality|
      counts[quality] = apply_quality_count(scope, quality)
    end

    counts
  end

  def apply_quality_count(scope, quality)
    return unknown_quality_scope(scope).count if quality == 'unknown'

    scope.joins(:lead_qualification)
         .where(lead_qualifications: { quality: LeadQualification.qualities[quality] })
         .count
  end

  def filter_options
    {
      qualities: QUALITY_KEYS,
      follow_up_states: LeadQualification.follow_up_states.keys,
      booking_statuses: %w[booked no_booking canceled completed],
      assignees: assignee_options,
      sources: source_options
    }
  end

  def assignee_options
    User.where(id: visible_conversations.where.not(assignee_id: nil).select(:assignee_id))
        .order(:name)
        .map { |assignee| user_payload(assignee) }
  end

  def source_options
    Inbox.where(id: visible_conversations.select(:inbox_id))
         .includes(:channel)
         .order(:name)
         .map { |inbox| source_payload(inbox) }
  end

  def visible_contact_ids
    visible_conversations.select(:contact_id)
  end

  def visible_conversations
    @visible_conversations ||= begin
      scope = account.conversations
      if administrator?
        scope
      else
        inbox_ids = user.inboxes.where(account: account).select(:id)
        team_ids = user.teams.where(account: account).select(:id)
        scope.where(assignee_id: user.id)
             .or(scope.where(inbox_id: inbox_ids))
             .or(scope.where(team_id: team_ids))
      end
    end
  end

  def contacts_for_assignee(assignee_id)
    return visible_conversations.where(assignee_id: nil).select(:contact_id) if assignee_id == 'unassigned'
    return visible_conversations.where(assignee_id: user.id).select(:contact_id) if assignee_id == 'me'

    visible_conversations.where(assignee_id: assignee_id).select(:contact_id)
  end

  def booked_contact_ids
    Booking.where(account: account, status: :confirmed).select(:contact_id)
  end

  def preload_context_for(contacts)
    ids = contacts.map(&:id)
    @conversation_by_contact = latest_conversation_by_contact(ids)
    @conversations_by_contact = conversations_by_contact(ids)
    @bookings_by_contact = bookings_by_contact(ids)
    @follow_ups_by_contact = follow_ups_by_contact(ids)
    @evidence_by_contact = evidence_by_contact(ids)
    conversation_ids = @conversation_by_contact.values.map(&:id)
    @latest_message_by_conversation = messages_by_position(conversation_ids, :last)
    @first_message_by_conversation = messages_by_position(conversation_ids, :first)
    @message_counts = Message.where(account: account, conversation_id: conversation_ids)
                             .unscope(:order)
                             .group(:conversation_id)
                             .count
  end

  def latest_conversation_by_contact(contact_ids)
    conversations_by_contact(contact_ids).transform_values(&:first)
  end

  def conversations_by_contact(contact_ids)
    visible_conversations
      .where(contact_id: contact_ids)
      .includes(:assignee, :inbox)
      .order(last_activity_at: :desc, id: :desc)
      .group_by(&:contact_id)
  end

  def bookings_by_contact(contact_ids)
    Booking.where(account: account, contact_id: contact_ids)
           .includes(:assignee)
           .order(starts_at: :desc, id: :desc)
           .group_by(&:contact_id)
  end

  def follow_ups_by_contact(contact_ids)
    LeadFollowUp.pending
                .where(account: account, contact_id: contact_ids)
                .order(scheduled_at: :asc, id: :asc)
                .group_by(&:contact_id)
  end

  def evidence_by_contact(contact_ids)
    QualificationEvidence.current
                         .where(account: account, contact_id: contact_ids)
                         .order(observed_at: :desc, id: :desc)
                         .group_by(&:contact_id)
  end

  def messages_by_position(conversation_ids, position)
    ordered = Message.where(account: account, conversation_id: conversation_ids).non_activity_messages
    ordered = if position == :first
                ordered.reorder(created_at: :asc, id: :asc)
              else
                ordered.reorder(created_at: :desc, id: :desc)
              end
    ordered.group_by(&:conversation_id).transform_values(&:first)
  end

  def latest_conversation_for(contact)
    @conversation_by_contact.fetch(contact.id, nil)
  end

  def conversations_for_contact(contact)
    @conversations_by_contact.fetch(contact.id, [])
  end

  def latest_booking_for(contact)
    bookings_for_contact(contact).first
  end

  def bookings_for_contact(contact)
    @bookings_by_contact.fetch(contact.id, [])
  end

  def next_follow_up_for(contact)
    @follow_ups_by_contact.fetch(contact.id, []).first
  end

  def current_evidence_for(contact)
    @evidence_by_contact.fetch(contact.id, [])
  end

  def latest_message_for(conversation)
    @latest_message_by_conversation.fetch(conversation.id, nil)
  end

  def first_message_for(conversation)
    @first_message_by_conversation.fetch(conversation.id, nil)
  end

  def message_counts
    @message_counts || {}
  end

  def business_name_for(contact)
    contact.additional_attributes&.dig('company_name').presence ||
      contact.additional_attributes&.dig('business_name').presence ||
      contact.additional_attributes&.dig('company').presence
  end

  def location_for(contact)
    [
      contact.additional_attributes&.dig('city'),
      contact.additional_attributes&.dig('country')
    ].compact_blank.join(', ').presence || contact.location.presence || contact.additional_attributes&.dig('location')
  end

  def user_payload(assignee)
    return if assignee.blank?

    { id: assignee.id, name: assignee.name, email: assignee.email, initials: initials_for(assignee.name) }
  end

  def source_payload(inbox)
    return if inbox.blank?

    { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
  end

  def initials_for(name)
    name.to_s.split.first(2).map { |part| part.first&.upcase }.join.presence || 'L'
  end

  def current_page
    [params[:page].to_i, 1].max
  end

  def per_page
    requested = params[:per_page].presence || DEFAULT_PER_PAGE
    requested.to_i.clamp(1, MAX_PER_PAGE)
  end

  def administrator?
    @administrator ||= account.account_users.find_by(user: user)&.administrator?
  end
end
# rubocop:enable Metrics/ClassLength
