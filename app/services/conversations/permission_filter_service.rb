class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, **_options)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    AiLeadEmployee::AccessScope.new(account: account, user: user).conversations(conversations)
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
