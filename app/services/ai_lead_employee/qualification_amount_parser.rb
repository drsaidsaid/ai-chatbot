# frozen_string_literal: true

require 'bigdecimal'

# Recognizes an amount; it deliberately makes no purchasing-eligibility decision.
class AiLeadEmployee::QualificationAmountParser
  NUMBER = /(?<![\w.])(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?/
  SWAHILI_NUMBERS = {
    'moja' => 1, 'mbili' => 2, 'tatu' => 3, 'nne' => 4, 'tano' => 5,
    'sita' => 6, 'saba' => 7, 'nane' => 8, 'tisa' => 9, 'kumi' => 10,
    'ishirini' => 20, 'thelathini' => 30, 'arobaini' => 40, 'hamsini' => 50,
    'sitini' => 60, 'sabini' => 70, 'themanini' => 80, 'tisini' => 90
  }.freeze
  SCALES = { 'milioni' => 1_000_000, 'laki' => 100_000, 'elfu' => 1000 }.freeze
  COEFFICIENT = /(?:#{SWAHILI_NUMBERS.keys.join('|')}|\d+(?:\.\d+)?)/
  SCALED_AMOUNT = /\b(milioni|laki|elfu)\s+(#{COEFFICIENT}(?:\s+na\s+#{COEFFICIENT})?)\b/
  SCALED_SEQUENCE = /\A#{SCALED_AMOUNT}(?:\s+(?:na\s+)?#{SCALED_AMOUNT})*\z/
  CURRENCY_TOKEN = /\b(?:tzs|tshs?|usd|kes|ugx|eur|gbp)\b|\$/
  NEGATIVE_AMOUNT = /[-−]\s*(?:(?:#{CURRENCY_TOKEN}|shilingi)\s*)*(?:\d|milioni\b|laki\b|elfu\b)/

  def self.parse(text)
    text = text.to_s.downcase
    return if text.match?(/\b(?:or|au|between|kati|nusu|billion|bilioni)\b/) || text.match?(NEGATIVE_AMOUNT)

    currencies = currencies(text)
    return if currencies.size > 1

    amount = text.match?(/\b(?:milioni|laki|elfu)\b/) ? swahili_amount(text) : numeric_amount(text)
    minor = minor_units(amount)
    return unless minor

    { 'amount_minor' => minor, 'currency' => currencies.first }
  end

  def self.minor_units(amount)
    return unless amount

    minor = amount * 100
    minor.to_i if minor.frac.zero? && minor <= 9_007_199_254_740_991
  end

  def self.currencies(text)
    text.scan(CURRENCY_TOKEN).map do |token|
      case token
      when 'tsh', 'tshs' then 'TZS'
      when '$' then 'USD' # Existing pilot compatibility, not an inferred FX rate.
      else token.upcase
      end
    end.uniq
  end

  def self.numeric_amount(text)
    matches = text.to_enum(:scan, NUMBER).map { Regexp.last_match }
    return unless matches.one?

    match = matches.first
    multiplier = case text[match.end(0)..].to_s
                 when /\A\s*(?:k|thousand)\b/ then 1000
                 when /\A\s*million\b/ then 1_000_000
                 else 1
                 end
    BigDecimal(match[0].delete(',')) * multiplier
  end

  def self.swahili_amount(text)
    matches = text.scan(SCALED_AMOUNT)
    return if matches.empty?
    return unless complete_swahili_amount?(text)

    coefficients = matches.map { |_scale, words| swahili_coefficient(words) }
    return if coefficients.any?(&:nil?)

    matches.zip(coefficients).sum { |(scale, _words), coefficient| coefficient * SCALES.fetch(scale) }
  end

  def self.complete_swahili_amount?(text)
    amount = text.gsub(CURRENCY_TOKEN, '').gsub(/\bshilingi\b/, '').strip
    amount = amount.sub(/\s+(?:kwa mwezi|kwa mwaka|per month|monthly)\.?\z/, '').delete_suffix('.')
    amount.match?(SCALED_SEQUENCE)
  end

  def self.swahili_coefficient(words)
    parts = words.split(/\s+na\s+/).map do |word|
      SWAHILI_NUMBERS.key?(word) ? BigDecimal(SWAHILI_NUMBERS.fetch(word).to_s) : BigDecimal(word)
    end
    return parts.first if parts.one?

    tens, ones = parts
    tens + ones if tens.between?(10, 90) && (tens % 10).zero? && ones.between?(1, 9)
  end
end
