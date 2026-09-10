module Whatsapp::RecipientIdentifier
  def self.normalize(value)
    identifier = value.to_s.strip
    return identifier if identifier.match?(RegexHelper::WHATSAPP_BSUID_REGEX)

    identifier.delete('^0-9').presence
  end
end
