# frozen_string_literal: true

class AiLeadEmployee::LanguageDetector
  SWAHILI_TOKENS = %w[
    asante biashara habari hali jina karibu kama kuhusu kujua kuongea lugha maelezo
    mambo malalamiko msaada nahitaji naitwa naomba nataka ndio ndiyo nimelipa ningependa nini sawa sijui siwezi tafadhali unaongea utapeli
  ].freeze

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
