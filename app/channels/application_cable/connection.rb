class ApplicationCable::Connection < ActionCable::Connection::Base
  def authenticated_user
    AiLeadEmployee::BrowserSession.user(cookies)
  end
end
