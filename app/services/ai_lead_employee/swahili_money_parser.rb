# frozen_string_literal: true

class AiLeadEmployee::SwahiliMoneyParser
  NUMBER_WORDS = %w[moja mbili tatu nne tano kumi ishirini thelathini arobaini hamsini]
                 .zip([1, 2, 3, 4, 5, 10, 20, 30, 40, 50]).to_h.freeze
  NUMBER_TOKEN = /#{NUMBER_WORDS.keys.join('|')}/i
  SCALE_TOKEN = /milioni|bilioni|laki|elfu|mia/i
  MONETARY_SPAN_PATTERN = /\b(?:#{SCALE_TOKEN})\s+[\p{L}\d]+(?:\s+na\s*(?:(?:#{SCALE_TOKEN})\s+)?[\p{L}\d]+)*\b/i
  AMOUNT_PATTERN = /\A(?:
    laki\s+(?<laki>#{NUMBER_TOKEN})(?:\s+na\s+elfu\s+(?<laki_elfu>#{NUMBER_TOKEN}(?:\s+na\s+#{NUMBER_TOKEN})?))?|
    elfu\s+(?<elfu>#{NUMBER_TOKEN}(?:\s+na\s+#{NUMBER_TOKEN})?)
  )\z/ix

  def self.amounts(text)
    monetary_spans(text).filter_map do |span|
      match = AMOUNT_PATTERN.match(span)
      next unless match

      if match[:laki]
        (number(match[:laki]) * 100_000) + (number(match[:laki_elfu]) * 1_000)
      else
        number(match[:elfu]) * 1_000
      end
    end
  end

  def self.monetary_language?(text)
    text.match?(MONETARY_SPAN_PATTERN) || text.match?(/\b(?:elfu|laki)\b/i)
  end

  def self.unresolved?(text)
    monetary_spans(text).any? { |span| !span.match?(AMOUNT_PATTERN) }
  end

  def self.monetary_spans(text)
    text.to_s.scan(MONETARY_SPAN_PATTERN)
  end
  private_class_method :monetary_spans

  def self.number(value)
    value.to_s.split(/\s+na\s+/i).sum { |word| NUMBER_WORDS.fetch(word.downcase, 0) }
  end
  private_class_method :number
end
