# frozen_string_literal: true

# The fixed-role boundary shared by HTTP queries and asynchronous work.
class AiLeadEmployee::AccessScope
  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def membership
    return unless @account && @user.is_a?(User)

    AccountUser.find_by(account_id: @account.id, user_id: @user.id)
  end

  def administrator?
    membership&.administrator? || false
  end

  def conversations(scope = Conversation.all)
    scoped = scope.where(account_id: @account&.id)
    member = membership
    return scoped.none unless member
    return scoped if member.administrator?

    scoped.where(assignee_id: @user.id)
  end

  def contacts(scope = Contact.all)
    scoped = scope.where(account_id: @account&.id)
    return scoped if administrator?

    scoped.where(id: conversations.select(:contact_id))
  end

  def complete_contact_ids
    hidden = Conversation.where(account_id: @account&.id).where.not(id: conversations.select(:id))
    contacts.where.not(id: hidden.select(:contact_id)).select(:id)
  end

  def complete_contact?(contact)
    administrator? || complete_contact_ids.exists?(id: contact.id)
  end

  def qualifications(scope = LeadQualification.all)
    scoped = scope.where(account_id: @account&.id)
    return scoped if administrator?

    scoped.where(contact_id: complete_contact_ids)
  end

  def qualification(contact)
    return unless contact

    qualifications.find_by(contact_id: contact.id)
  end

  def related(scope)
    scoped = scope.where(account_id: @account&.id)
    return scoped if administrator?

    scoped.where(conversation_id: conversations.select(:id))
  end
end
