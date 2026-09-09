# frozen_string_literal: true

class AiLeadEmployee::RealtimeDelivery
  SAFE_EVENTS = %w[account.cache_invalidated conversation.unread_count_changed notification.deleted access.changed presence.update].freeze

  def initialize(members:, event:, data:)
    @members = members
    @event = event
    @data = data.with_indifferent_access
    @account = Account.find_by(id: @data[:account_id])
  end

  def perform
    return unless @account

    tokens.each do |token|
      user = User.find_by(pubsub_token: token)
      next unless user ? permitted_user?(user) : permitted_contact?(token)

      payload = user ? dashboard_payload(@data.as_json) : @data
      ActionCable.server.broadcast(token, { event: @event, data: payload })
    end
  end

  def authorized_user?(user)
    @account && permitted_user?(user)
  end

  private

  # Contact widget credentials must never be handed to a dashboard recipient.
  def dashboard_payload(value)
    case value
    when Hash
      value.except('pubsub_token').transform_values { |nested| dashboard_payload(nested) }
    when Array
      value.map { |nested| dashboard_payload(nested) }
    else
      value
    end
  end

  def tokens
    @members.flat_map do |member|
      member == "account_#{@account.id}" ? @account.users.pluck(:pubsub_token) : member
    end.uniq
  end

  def permitted_user?(user)
    access = AiLeadEmployee::AccessScope.new(account: @account, user: user)
    return false unless access.membership
    return true if SAFE_EVENTS.include?(@event)
    return access.contacts.exists?(id: @data[:id]) if @event.start_with?('contact.')
    return access.conversations.exists?(id: conversation.id) if conversation

    access.administrator?
  end

  def conversation
    return @conversation if defined?(@conversation)

    @conversation = message_conversation || notification_conversation || referenced_conversation
  end

  def message_conversation
    return unless @event.start_with?('message.') || @event == 'first_reply.created'

    @account.messages.find_by(id: @data[:id])&.conversation
  end

  def notification_conversation
    return unless @event.start_with?('notification.')

    notification = @account.notifications.find_by(id: @data.dig(:notification, :id))
    notification&.primary_actor if notification&.primary_actor_type == 'Conversation'
  end

  def referenced_conversation
    display_id = if @data[:conversation].is_a?(Hash)
                   @data.dig(:conversation, :id)
                 elsif @event.start_with?('conversation.', 'assignee.', 'team.')
                   @data[:id]
                 end
    @account.conversations.find_by(display_id: display_id) if display_id
  end

  def permitted_contact?(token)
    return false unless conversation
    return false if @data[:private] || @data[:message_type] == Message.message_types['activity']

    conversation.contact.contact_inboxes.joins(:inbox).exists?(inboxes: { account_id: @account.id }, pubsub_token: token)
  end
end
