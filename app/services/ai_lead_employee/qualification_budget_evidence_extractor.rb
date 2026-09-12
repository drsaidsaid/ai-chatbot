# frozen_string_literal: true

# Locates a stated purchase budget, capacity or allocation before parsing money.
class AiLeadEmployee::QualificationBudgetEvidenceExtractor
  AMOUNT_PREFIX = /\A(?:\d|#{AiLeadEmployee::QualificationAmountParser::CURRENCY_TOKEN}|shilingi\b|milioni\b|laki\b|elfu\b)/
  ALLOCATION = /\b(?:ninaweza kutenga|naweza kutenga|nimetenga|ninatenga|nitatenga|(?:i|we) (?:have )?(?:set aside|allocated))\s+(.+)/
  CAPACITY = /\b(?:(?:i|we|and) can spend|(?:ninaweza|naweza|tunaweza) kutumia)\s+(.+)/
  PURCHASE_PURPOSE = /\A(?:this|this purchase|the purchase|this offer|this service|hii|huduma hii|ununuzi huu)[.!]*\z/
  DENIED_ALLOCATION = /\b(?:no|do not have any|don't have any) (?:money|funds) (?:allocated|set aside|available)\b/
  UNCERTAIN_ALLOCATION = /\b(?:or|au|between|kati|if|depending|depends|assuming|subject to|inategemea|kama|ikiwa)\b/
  CONTACT_CLAUSE = /(?:,\s*(?:and\s+)?|\s+and\s+)(?:i|we)\s+can be reached\b[^,]*?(?=,|\s+and\b|\z)/

  def self.financial_statement?(content)
    content.match?(Regexp.union(CAPACITY, ALLOCATION, /\b(?:budget|bajeti)\b/))
  end

  def initialize(content, contextual: false)
    @content = content
    @contextual = contextual
    @basis = 'stated_budget'
  end

  attr_reader :basis

  def value
    fragment = allocation_fragment
    return 'unknown' if restricted_continuation?
    return contextual_value if fragment.nil? && contextual
    return unless fragment
    return 'unknown' if uncertain_claim?
    return 'no budget' if denied_budget?

    normalized_value(fragment)
  end

  private

  attr_reader :content, :contextual

  def uncertain_claim?
    content.match?(AiLeadEmployee::QualificationEvidenceExtractor::UNKNOWN) ||
      (basis == 'capacity' && @capacity_prefix.to_s.match?(UNCERTAIN_ALLOCATION))
  end

  def restricted_continuation?
    return false unless self.class.financial_statement?(content)

    content.match?(/\b(?:but|lakini)\b/)
  end

  def allocation_fragment
    return content.split(/\b(?:budget|bajeti)\b/, 2).last if content.match?(/\b(?:budget|bajeti)\b/)
    return '' if content.match?(DENIED_ALLOCATION)

    allocation = content.match(ALLOCATION)
    if allocation
      @basis = allocation[0].match?(/\b(?:ninaweza|naweza)\b/) ? 'capacity' : 'allocation'
      @capacity_prefix = allocation.pre_match
      return allocation[1]
    end

    capacity_fragment
  end

  def capacity_fragment
    capacity = content.match(CAPACITY)
    return unless capacity

    @capacity_prefix = capacity.pre_match
    fragment = capacity[1].gsub(CONTACT_CLAUSE, '')
    before_condition = fragment.split(UNCERTAIN_ALLOCATION, 2).first.to_s.strip.delete_suffix(',')
    amount, purpose = before_condition.split(/\s+(?:for|on|kwa)\s+/, 2)
    return if purpose && !purpose.match?(PURCHASE_PURPOSE)

    @basis = 'capacity'
    fragment.match?(UNCERTAIN_ALLOCATION) ? fragment : amount
  end

  def denied_budget?
    return true if content.match?(DENIED_ALLOCATION)
    return true if content.match?(/\b(?:bajeti|budget)\b.*\b(?:imeisha|haipo|withdrawn|unavailable)\b/)

    content.match?(/\b(?:no longer have|no|do not have|don't have|sina|hakuna)\b.{0,30}\b(?:budget|bajeti)\b/)
  end

  def normalized_value(fragment)
    fragment = fragment.to_s.gsub(CONTACT_CLAUSE, '')
    return 'unknown' if fragment.match?(UNCERTAIN_ALLOCATION)

    fragment = fragment.to_s.split(/,\s+|\s+and\s+(?=i\b|we\b)/).first.to_s.strip
    fragment = fragment.sub(/\Afor\b.{1,80}?\bis\s+/, '').sub(/\A(?:(?:is|of|actually|yangu|ni|ya)\s+)*/, '')
    fragment = fragment.split(/\s+(?:kwa|for)\s+/, 2).first.to_s.sub(/[.!?]+\z/, '')
    return 'unknown' unless fragment.match?(AMOUNT_PREFIX)

    AiLeadEmployee::QualificationAmountParser.parse(fragment) ? fragment : 'unknown'
  end

  def contextual_value
    return if content.match?(/\b(?:salary|revenue|profit|mshahara|mapato|faida)\b/)
    return 'no budget' if content.match?(/\A(?:none|nothing|zero|sina|hakuna|sina pesa)[.!]*\z/)

    normalized_value(content) if content.match?(AMOUNT_PREFIX) || content.match?(/\A[-−]/)
  end
end
