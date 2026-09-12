# frozen_string_literal: true

require 'uri'

class AiLeadEmployee::CommercialClaimValidator
  AMOUNT = /(?:\b(?:USD|TZS|KES|EUR|GBP)\s*|[$€£]\s*)\d[\d,.]*/i
  URL = %r{https?://[^\s<>)]+}i
  CONTROLLED_CLAIMS = {
    guarantee: %w[guarantee guarantees guaranteed dhamana uhakika kuhakikishwa yamehakikishwa hayajahakikishwa],
    eligibility: %w[eligibility eligible qualify qualifies ustahiki stahili anastahili unastahili hustahili],
    refund: %w[refund refunds refundable marejesho kurejeshewa]
  }.freeze
  NEGATIONS = %w[
    no not never without cannot can't hakuna si sio hapana hayapatikani haipatikani hapatikani
    hayajahakikishwa hajahakikishwa haijahakikishwa hustahili hastahili hawastahili
  ].freeze

  def initialize(approved_content:, candidate_content:)
    @approved_content = approved_content.to_s
    @candidate_content = candidate_content.to_s
  end

  def valid?
    subset?(AMOUNT) && subset?(URL) && controlled_terms_supported?
  end

  private

  attr_reader :approved_content, :candidate_content

  def subset?(pattern)
    (normalized_matches(candidate_content, pattern) - normalized_matches(approved_content, pattern)).empty?
  end

  def normalized_matches(content, pattern)
    content.scan(pattern).map { |value| value.to_s.downcase.delete_suffix('.').gsub(/[,_]/, '') }.uniq
  end

  def controlled_terms_supported?
    candidate_claims = CONTROLLED_CLAIMS.select { |_, terms| mentions_claim?(candidate_content, terms) }
    candidate_claims.all? do |_, terms|
      mentions_claim?(approved_content, terms) &&
        (!affirmative_claim?(candidate_content, terms) || affirmative_claim?(approved_content, terms))
    end
  end

  def mentions_claim?(content, terms)
    claim_clauses(content, terms).present?
  end

  def affirmative_claim?(content, terms)
    claim_occurrences(content, terms).any? do |words, index|
      window = words[[index - 5, 0].max..[index + 5, words.length - 1].min]
      !window.intersect?(NEGATIONS)
    end
  end

  def claim_clauses(content, terms)
    content.downcase.split(/[.!?;:]|\b(?:but|however|lakini|ila)\b/).filter_map do |clause|
      words = clause.scan(/[[:alpha:]]+/)
      words if words.intersect?(terms)
    end
  end

  def claim_occurrences(content, terms)
    claim_clauses(content, terms).flat_map do |words|
      words.each_index.filter_map { |index| [words, index] if terms.include?(words[index]) }
    end
  end
end
