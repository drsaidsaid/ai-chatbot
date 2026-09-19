# frozen_string_literal: true

class AiLeadEmployee::CommercialClaimClassifier
  CURRENCY_PATTERN = /(?:(?<currency>USD|TZS|KES|EUR|GBP)\s*(?<amount>\d[\d,]*(?:\.\d{1,2})?)|
                       (?<symbol>\$|TSh|Sh)\s*(?<symbol_amount>\d[\d,]*(?:\.\d{1,2})?))/ix
  PRICE_WORDS = /\b(price|prices|pricing|cost|costs|fee|fees|promotion|promotional|discount|sale|quote|bei|gharama|punguzo|nukuu)\b/i
  HARD_EXCLUDED_CONTEXT = /\b(lead|customer|client)\s+budget\b|
                           \b(platform\s+subscription|AI\s+reply\s+credit|Meta\s+charge|ad\s+spend)\b/ix
  FINANCIAL_CONTEXT = /\b(revenue|salary|income)\b/i
  FINANCIAL_METRIC = /\b(?:revenue|salary|income)\s+
                       (?:is|are|was|were|of|totals?|equals?|below|above|under|over|
                       less\s+than|more\s+than|at\s+least|up\s+to)\b/ix
  COMMERCIAL_SUBJECT = /\b(coaching|consulting|course|service|training|program(?:me)?|product|offer|package|plan|huduma|mafunzo)\b/i
  CONFIDENT_NAMED_FINANCIAL_OFFER = /\b(?:revenue|salary|income)\s+#{COMMERCIAL_SUBJECT}[^.!?]*#{PRICE_WORDS}/io
  SUBJECT_PRICE_BEFORE_FINANCIAL = /#{COMMERCIAL_SUBJECT}[^.!?]*#{PRICE_WORDS}[^.!?]*#{FINANCIAL_CONTEXT}/io
  OFFER_PRICE_PREDICATE = /(?:#{COMMERCIAL_SUBJECT}[^.!?]*#{PRICE_WORDS}|#{PRICE_WORDS}[^.!?]*#{COMMERCIAL_SUBJECT})/io
  CLAUSE_SEPARATOR = /\s+(?:but|while|whereas|lakini)\s+|;+|,(?=\s+)/i
  SHARED_FINANCIAL_SUBJECT = /\b(?:revenue|salary|income)\s+and\s+#{COMMERCIAL_SUBJECT}/io
  SHARED_PRICE_VALUES = /#{PRICE_WORDS}[^.!?]*\s+and\s+(?:(?:USD|TZS|KES|EUR|GBP|\$|TSh|Sh)\s*\d|(?:elfu|laki|milioni|bilioni|mia)\b)/io

  def self.approved_clauses(sentence, offer_name: nil)
    clauses(sentence).reject { |clause| unsafe_for_knowledge?(clause, offer_name: offer_name) }
  end

  def self.clauses(sentence)
    sentence.to_s.split(CLAUSE_SEPARATOR).flat_map do |clause|
      clause.match?(SHARED_FINANCIAL_SUBJECT) || clause.match?(SHARED_PRICE_VALUES) ? clause : clause.split(/\s+and\s+/i)
    end.map(&:strip).reject(&:blank?)
  end

  def self.commercial?(clause, offer_name: nil) = classify(clause, offer_name: offer_name) == :commercial
  def self.unresolved?(clause, offer_name: nil) = classify(clause, offer_name: offer_name) == :ambiguous

  def self.unsafe_for_knowledge?(clause, offer_name: nil)
    %i[commercial ambiguous].include?(classify(clause, offer_name: offer_name))
  end

  def self.classify(clause, offer_name: nil)
    return :general unless monetary_or_price_claim?(clause)
    return :ambiguous if AiLeadEmployee::SwahiliMoneyParser.unresolved?(clause)
    return classify_hard_excluded(clause) if clause.match?(HARD_EXCLUDED_CONTEXT)
    return classify_financial(clause, offer_name) if clause.match?(FINANCIAL_CONTEXT)

    confident_offer_claim?(clause, offer_name) ? :commercial : :ambiguous
  end

  def self.classify_hard_excluded(clause)
    clause.match?(COMMERCIAL_SUBJECT) && clause.match?(PRICE_WORDS) ? :ambiguous : :non_offer
  end

  def self.classify_financial(clause, offer_name)
    metric_classification = classify_financial_metric(clause, offer_name)
    return metric_classification if metric_classification
    return :commercial if offer_identity?(clause, offer_name)
    return :commercial if clause.match?(CONFIDENT_NAMED_FINANCIAL_OFFER) || clause.match?(SUBJECT_PRICE_BEFORE_FINANCIAL)

    :ambiguous
  end

  def self.classify_financial_metric(clause, offer_name)
    metric_match = clause.match(FINANCIAL_METRIC)
    return unless metric_match

    identity_match = offer_identity_match(clause, offer_name)
    return :commercial if trusted_identity_overlap?(clause, offer_name, metric_match, identity_match)
    return :ambiguous if distinct_identity_with_multiple_amounts?(clause, metric_match, identity_match)
    return :ambiguous if clause.match?(OFFER_PRICE_PREDICATE)

    :non_offer
  end

  def self.confident_offer_claim?(clause, offer_name)
    clause.match?(PRICE_WORDS) || clause.match?(COMMERCIAL_SUBJECT) || offer_identity?(clause, offer_name)
  end

  def self.monetary_claim?(clause)
    clause.match?(CURRENCY_PATTERN) || AiLeadEmployee::SwahiliMoneyParser.monetary_language?(clause)
  end

  def self.monetary_or_price_claim?(clause) = clause.match?(PRICE_WORDS) || monetary_claim?(clause)

  def self.offer_identity?(clause, offer_name)
    offer_identity_match(clause, offer_name).present?
  end

  def self.offer_identity_match(clause, offer_name)
    tokens = offer_name.to_s.scan(/[\p{L}\p{N}]+/)
    return if tokens.empty?

    phrase = tokens.map { |token| Regexp.escape(token) }.join('\\s+')
    clause.match(Regexp.new("(?<![\\p{L}\\p{N}])#{phrase}(?![\\p{L}\\p{N}])", Regexp::IGNORECASE))
  end

  def self.overlapping_matches?(first, second)
    first && second && first.begin(0) < second.end(0) && second.begin(0) < first.end(0)
  end

  def self.trusted_identity_overlap?(clause, offer_name, metric_match, identity_match)
    return false unless overlapping_matches?(metric_match, identity_match)
    return true if offer_name.to_s.scan(/[\p{L}\p{N}]+/).many?

    tail = clause[metric_match.end(0)..]
    first_money = tail.match(CURRENCY_PATTERN)
    before_money = first_money ? tail[0...first_money.begin(0)] : tail
    before_money.match?(COMMERCIAL_SUBJECT) || before_money.match?(PRICE_WORDS)
  end

  def self.distinct_identity_with_multiple_amounts?(clause, metric_match, identity_match)
    identity_match && !overlapping_matches?(metric_match, identity_match) && monetary_value_count(clause) > 1
  end

  def self.monetary_value_count(clause)
    clause.to_enum(:scan, CURRENCY_PATTERN).count + AiLeadEmployee::SwahiliMoneyParser.amounts(clause).length
  end

  private_class_method :classify_hard_excluded, :classify_financial, :classify_financial_metric,
                       :confident_offer_claim?, :monetary_claim?, :monetary_or_price_claim?, :offer_identity?,
                       :offer_identity_match, :overlapping_matches?, :trusted_identity_overlap?,
                       :distinct_identity_with_multiple_amounts?, :monetary_value_count
end
