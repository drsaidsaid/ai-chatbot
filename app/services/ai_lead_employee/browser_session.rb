# frozen_string_literal: true

# A read-only bridge for native media requests that cannot send dashboard headers.
class AiLeadEmployee::BrowserSession
  COOKIE = :ale_media_session

  def self.user(cookies)
    session = cookies.encrypted[COOKIE]&.with_indifferent_access
    return unless session

    user = User.find_by(id: session[:user_id])
    user if user&.valid_token?(session[:token], session[:client])
  end

  def self.capture(cookies:, request:, response:)
    token, client, uid = %w[access-token client uid].map { |header| response.headers[header].presence || request.headers[header] }
    return if [token, client, uid].any?(&:blank?)

    user = User.find_by(uid: uid)
    return unless user&.valid_token?(token, client)

    cookies.encrypted[COOKIE] = {
      value: { user_id: user.id, token: token, client: client },
      httponly: true, secure: request.ssl?, same_site: :strict,
      expires: Time.zone.at(user.tokens.fetch(client).fetch('expiry'))
    }
  end
end
