# frozen_string_literal: true

require_relative 'information_request'

class AiLeadEmployee::LanguageDetector
  SWAHILI_TOKENS = (%w[
    asante biashara habari hali jina karibu kama kuhusu kujua kuongea lugha maelezo
    kujiunga mambo malalamiko mnakubali mnasafirisha msaada mtandaoni nahitaji naitwa naomba nataka ndio ndiyo nimelipa
    hapana huduma je jinsi labda lini mna mnafundisha naam naweza ndiyo ndivyo ni ninaweza ningependa nini sawa
    sijui simaanishi siwezi tafadhali unaongea utapeli wapi ukoje mkoje ikoje
  ] + AiLeadEmployee::InformationRequest::SWAHILI_LANGUAGE_TOKENS).uniq.freeze

  def self.detect(content)
    new(content).detect
  end

  def initialize(content)
    @content = content.to_s
  end

  def detect
    return :swahili if swahili?

    :english
  end

  private

  attr_reader :content

  def swahili?
    normalized_tokens.intersect?(SWAHILI_TOKENS)
  end

  def normalized_tokens
    content.downcase.gsub(/[^[:alnum:]\s]/, ' ').split
  end
end
