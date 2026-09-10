class ActionCableBroadcastJob < ApplicationJob
  queue_as :critical
  include Events::Types

  CONVERSATION_UPDATE_EVENTS = [
    CONVERSATION_READ,
    CONVERSATION_UPDATED,
    TEAM_CHANGED,
    ASSIGNEE_CHANGED,
    CONVERSATION_STATUS_CHANGED
  ].freeze

  def perform(members, event_name, data)
    return if members.blank?

    broadcast_data = prepare_broadcast_data(event_name, data)
    return if broadcast_data.blank?

    broadcast_to_members(members, event_name, broadcast_data)
  end

  private

  # Ensures that only the latest available data is sent to prevent UI issues
  # caused by out-of-order events during high-traffic periods. This prevents
  # jobs from publishing an older Message instance or Conversation snapshot.
  def prepare_broadcast_data(event_name, data)
    if [MESSAGE_CREATED, MESSAGE_UPDATED].include?(event_name)
      message = Message.find_by(id: data[:id], account_id: data[:account_id])
      return if message.nil?

      metadata = data.slice(:previous_changes, :performer)
      metadata[:echo_id] = data[:echo_id] if event_name == MESSAGE_CREATED && data.key?(:echo_id)
      return message.push_event_data.merge(metadata)
    end

    return data unless CONVERSATION_UPDATE_EVENTS.include?(event_name)

    account = Account.find(data[:account_id])
    conversation = account.conversations.find_by!(display_id: data[:id])
    conversation.push_event_data.merge(account_id: data[:account_id])
  end

  def broadcast_to_members(members, event_name, broadcast_data)
    AiLeadEmployee::RealtimeDelivery.new(members: members, event: event_name, data: broadcast_data).perform
  end
end
