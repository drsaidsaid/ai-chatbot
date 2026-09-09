# frozen_string_literal: true

class AiLeadEmployee::BlobAccess
  def self.authorize_upload!(uploaded_attachment, user:)
    return unless user.is_a?(User) && uploaded_attachment.is_a?(String)

    blob = ActiveStorage::Blob.find_signed!(uploaded_attachment)
    raise Pundit::NotAuthorizedError unless new(blob: blob, user: user).allowed?
  end

  def initialize(blob:, user:)
    @blob = blob
    @user = user
  end

  def allowed?
    attachments = @blob.attachments.includes(:record).to_a
    return staged_upload? if attachments.empty?

    attachments.all? { |attachment| record_allowed?(attachment) }
  end

  private

  def staged_upload?
    metadata = @blob.metadata
    account = Account.find_by(id: metadata['r06_account_id'])
    access = AiLeadEmployee::AccessScope.new(account: account, user: @user)
    access.membership && metadata['r06_user_id'] == @user.id &&
      (metadata['r06_conversation_id'].blank? || access.conversations.exists?(id: metadata['r06_conversation_id']))
  end

  def record_allowed?(attachment)
    record = attachment.record
    return false unless record
    return self.class.new(blob: record.blob, user: @user).allowed? if record.is_a?(ActiveStorage::VariantRecord)
    return true if public_avatar?(attachment)

    protected_record_allowed?(record)
  end

  def public_avatar?(attachment)
    attachment.name == 'avatar' && [User, Account].any? { |type| attachment.record.is_a?(type) }
  end

  def protected_record_allowed?(record)
    account = record.is_a?(Account) ? record : Account.find_by(id: record.try(:account_id))
    access = AiLeadEmployee::AccessScope.new(account: account, user: @user)
    return access.conversations.exists?(id: record.message.conversation_id) if record.is_a?(Attachment)
    return access.contacts.exists?(id: record.id) if record.is_a?(Contact)

    access.administrator?
  end
end
