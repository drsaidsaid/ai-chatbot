# frozen_string_literal: true

class AiLeadEmployee::OfferMoney
  # This V1 subset has two fractional digits. Other currencies are unsupported.
  PRECISION = { 'TZS' => 2, 'USD' => 2, 'KES' => 2, 'EUR' => 2, 'GBP' => 2 }.freeze

  def self.parse(value, currency)
    precision = PRECISION.fetch(currency) { raise ArgumentError, 'Unsupported currency' }
    return if value.nil? || value == ''

    text = value.to_s
    raise ArgumentError, 'Enter a nonnegative amount with supported currency precision' unless text.match?(/\A\d+(?:\.\d{1,#{precision}})?\z/)

    amount = (BigDecimal(text) * (10**precision)).to_i
    raise ArgumentError, 'Amount is too large' if amount > 9_007_199_254_740_991

    amount
  end

  def self.format(minor, currency)
    return if minor.nil?

    precision = PRECISION.fetch(currency)
    major, fraction = minor.divmod(10**precision)
    "#{major}.#{fraction.to_s.rjust(precision, '0')}"
  end
end
