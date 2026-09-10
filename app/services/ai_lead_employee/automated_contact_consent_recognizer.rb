# frozen_string_literal: true

class AiLeadEmployee::AutomatedContactConsentRecognizer
  STOP_PATTERNS = [
    /\A(?:please\s+)?(?:stop|unsubscribe|opt\s+out)\z/,
    /\b(?:please\s+)?stop\s+(?:sending|messaging|contacting)\s+me\b/,
    /\b(?:do\s+not|don\s+t|dont|never)\s+(?:send|message|contact)\s+me\b/,
    /\bno\s+more\s+(?:messages|texts)\b/,
    /\b(?:tafadhali\s+)?(?:acha|acheni)\s+kunitumia\s+(?:ujumbe|meseji|messages)\b/,
    /\b(?:tafadhali\s+)?usinitumie\s+(?:ujumbe|meseji|messages)(?:\s+tena)?\b/,
    /\bsitaki\s+(?:kupokea\s+)?(?:ujumbe|meseji|messages)\s+(?:tena|zaidi)\b/,
    /\bstop\s+kunitumia\s+(?:ujumbe|meseji|messages)\b/
  ].freeze

  INFORMATIONAL_PATTERNS = [
    /\A(?:what\s+does|what\s+do|how\s+do|how\s+can|can\s+you\s+explain|could\s+you\s+explain)\b/,
    /\A(?:does|is)\b.*\b(?:mean|refer\s+to)\b/
  ].freeze

  GRANT_PATTERNS = [
    /\A(?:yes\s+)?(?:please\s+)?(?:start|resume)\s+(?:sending|messaging|contacting)\s+me(?:\s+again)?\z/,
    /\A(?:yes\s+)?(?:please\s+)?you\s+can\s+(?:send|message|contact)\s+me(?:\s+again)?\z/,
    /\A(?:ndiyo\s+)?(?:tafadhali\s+)?(?:anza|endelea)\s+kunitumia\s+(?:ujumbe|meseji|messages)(?:\s+tena)?\z/,
    /\A(?:ndiyo\s+)?unaweza\s+kunitumia\s+(?:ujumbe|meseji|messages)\s+tena\z/
  ].freeze

  def self.explicit_grant?(text)
    matches?(text, GRANT_PATTERNS)
  end

  def self.withdrawal?(text)
    normalized = normalize(text)
    return false if INFORMATIONAL_PATTERNS.any? { |pattern| normalized.match?(pattern) }

    STOP_PATTERNS.any? { |pattern| normalized.match?(pattern) }
  end

  def self.normalize(text)
    text.to_s
        .gsub(/"[^"]*"|“[^”]*”|‘[^’]*’|(?:\A|\s)'[^']+'(?=\s|[[:punct:]]|\z)/, ' ')
        .downcase
        .gsub(/[^[:alnum:]\s]/, ' ')
        .squish
  end
  private_class_method :normalize

  def self.matches?(text, patterns)
    normalized = normalize(text)
    patterns.any? { |pattern| normalized.match?(pattern) }
  end
  private_class_method :matches?
end
