class ContactPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      AiLeadEmployee::AccessScope.new(account: account, user: user).contacts(scope)
    end
  end

  def index?
    allowed_contact?
  end

  def active?
    allowed_contact?
  end

  def import?
    access.administrator?
  end

  def export?
    access.administrator?
  end

  def search?
    allowed_contact?
  end

  def filter?
    allowed_contact?
  end

  def update?
    allowed_contact?
  end

  def reconsent?
    access.administrator?
  end

  def contactable_inboxes?
    allowed_contact?
  end

  def destroy_custom_attributes?
    allowed_contact?
  end

  def show?
    allowed_contact?
  end

  def create?
    access.administrator?
  end

  def avatar?
    allowed_contact?
  end

  def destroy?
    access.administrator?
  end

  private

  def access
    AiLeadEmployee::AccessScope.new(account: account, user: user)
  end

  def allowed_contact?
    return false unless access.membership
    return true if record == Contact

    access.contacts.exists?(id: record.id)
  end
end

ContactPolicy.prepend_mod_with('ContactPolicy')
