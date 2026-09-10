module Api::V1::Accounts::Concerns::ConversationConsentPreload
  extend ActiveSupport::Concern

  def index
    super
    preload_automated_contact_consent
  end

  def filter
    super
    preload_automated_contact_consent if @conversations
  end

  private

  def preload_automated_contact_consent
    conversations = @conversations.to_a
    @automated_contact_consent_by_contact = AiLeadEmployee::AutomatedContactConsentPresenter.preload(
      account: current_account,
      user: Current.user,
      contacts: conversations.map(&:contact)
    )
  end
end
