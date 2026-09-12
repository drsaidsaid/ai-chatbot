# frozen_string_literal: true

require 'uri'

class AiLeadEmployee::CommercialClaimValidator
  AMOUNT = /(?:\b(?:USD|TZS|KES|EUR|GBP)\s*|[$€£]\s*)\d[\d,.]*/i
  URL = %r{https?://[^\s<>)]+}i
  CONTROLLED_TERMS = %w[guarantee guaranteed eligibility eligible refund refunds].freeze
  NEGATIONS = %w[no not never without].freeze

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
    candidate_terms = CONTROLLED_TERMS.select { |term| candidate_content.downcase.match?(/\b#{term}\b/) }
    candidate_terms.all? do |term|
      approved_content.downcase.match?(/\b#{term}\b/) &&
        (!affirmative_claim?(candidate_content, term) || affirmative_claim?(approved_content, term))
    end
  end

  def affirmative_claim?(content, term)
    words = content.downcase.scan(/[a-z]+/)
    words.each_index.any? do |index|
      words[index] == term && !words[[index - 5, 0].max...index].intersect?(NEGATIONS)
    end
  end
end
