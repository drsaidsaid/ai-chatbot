# frozen_string_literal: true

class AiLeadEmployee::ExactOfferContextResolver
  def initialize(account:, message:)
    @account = account
    @message = message.to_s
  end

  def perform
    matches = account.qualification_offers.enabled_in_order.select { |offer| mentioned?(offer.name) }
    matches.one? ? matches.first : nil
  end

  private

  attr_reader :account, :message

  def mentioned?(offer_name)
    normalized_name = normalize(offer_name)
    return false if normalized_name.blank?

    normalized_message.match?(/(?:\A|\s)#{Regexp.escape(normalized_name)}(?:\z|\s)/)
  end

  def normalized_message
    @normalized_message ||= normalize(message)
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^[:alnum:]]+/, ' ').squish
  end
end
