# frozen_string_literal: true

class AiLeadEmployee::CommercialProposalExtractor
  CURRENCY_PATTERN = /(?:(?<currency>USD|TZS|KES|EUR|GBP)\s*(?<amount>\d[\d,]*(?:\.\d{1,2})?)|
                       (?<symbol>\$|TSh|Sh)\s*(?<symbol_amount>\d[\d,]*(?:\.\d{1,2})?))/ix
  PRICE_WORDS = /\b(price|pricing|cost|fee|promotion|promotional|discount|sale|quote)\b/i
  EXCLUDED_CONTEXT = /\b(lead|customer|client)\s+budget\b|\b(revenue|salary|income)\b|
                       \b(platform subscription|AI reply credit|Meta charge|ad spend)\b/ix

  def initialize(document:, offer:)
    @document = document
    @offer = offer
  end

  def perform
    candidates = extract_candidates
    return if candidates.empty?

    proposed = proposal_payload(candidates)
    conflict = conflict_details(proposed)
    offer.commercial_proposals.find_or_create_by!(knowledge_document: document, source_digest: source_digest) do |proposal|
      proposal.assign_attributes(
        account: offer.account,
        proposed_terms: proposed,
        conflict_details: conflict,
        status: conflict.present? ? :conflict_review : :pending
      )
    end
  end

  private

  attr_reader :document, :offer

  def extract_candidates
    sentences = document.body.to_s.split(/(?<=[.!?])\s+|\n+/)
    sentences.flat_map do |sentence|
      next [] if sentence.match?(EXCLUDED_CONTEXT)
      next [] unless sentence.match?(PRICE_WORDS)

      next [{ proposal_kind: 'quote_required', quote_required: true, sentence: sentence }] if quote_required?(sentence)

      monetary_candidates(sentence)
    end
  end

  def monetary_candidates(sentence)
    promotion = sentence.match?(/promotion|promotional|discount|sale/i)
    sentence.to_enum(:scan, CURRENCY_PATTERN).map do
      match = Regexp.last_match
      currency = match[:currency]&.upcase || symbol_currency(match[:symbol])
      amount = (match[:amount] || match[:symbol_amount]).delete(',')
      { proposal_kind: promotion ? 'promotion' : 'standard', amount: amount, currency: currency, sentence: sentence }
    end
  end

  def quote_required?(sentence)
    sentence.match?(/quote\s+(?:is\s+)?required|contact\s+.+\s+for\s+(?:a\s+)?quote/i)
  end

  def symbol_currency(symbol)
    return 'USD' if symbol == '$'
    return 'TZS' if symbol.to_s.casecmp('TSh').zero?

    offer.currency
  end

  def proposal_payload(candidates)
    base = apply_unambiguous_candidates(proposal_base(candidates), candidates)
    base.merge(
      'proposal_kinds' => candidates.pluck(:proposal_kind).uniq,
      'candidates' => candidates.map { |candidate| candidate.stringify_keys.except('sentence') },
      'extracted_text' => candidates.pluck(:sentence).join(' ')
    )
  end

  def proposal_base(candidates)
    base = offer.commercial_term&.draft_payload || offer.commercial_term&.published_payload || {
      'currency' => candidates.filter_map { |candidate| candidate[:currency] }.first || offer.currency,
      'quote_required' => false,
      'timezone' => 'UTC'
    }
    base.except('draft_version', 'revision', 'published_at')
  end

  def apply_unambiguous_candidates(base, candidates)
    distinct_candidates(candidates).group_by { |candidate| candidate[:proposal_kind] }.each_value do |kind_candidates|
      base = apply_candidate(base, kind_candidates.sole) if kind_candidates.one?
    end
    base
  end

  def apply_candidate(base, candidate)
    case candidate[:proposal_kind]
    when 'quote_required'
      base.merge('proposal_kind' => 'quote_required', 'quote_required' => true, 'amount' => nil)
    when 'promotion'
      promotion = { 'proposal_kind' => 'promotion', 'promotion_amount' => candidate[:amount] }
      promotion['promotion_currency'] = candidate[:currency] if base['currency'] != candidate[:currency]
      base.merge(promotion)
    else
      base.merge('proposal_kind' => 'standard', 'amount' => candidate[:amount], 'currency' => candidate[:currency],
                 'quote_required' => false)
    end
  end

  def conflict_details(proposed)
    return { 'reason' => 'Document contains contradictory commercial facts that require review' } if contradictory?(proposed)

    published = offer.commercial_term&.published_payload
    return {} unless published

    differs = published_conflict?(published, proposed)
    return {} unless differs

    {
      'published_amount' => published['amount'],
      'published_currency' => published['currency'],
      'published_quote_required' => published['quote_required'],
      'reason' => 'Document price conflicts with the authoritative published Offer price'
    }
  end

  def contradictory?(proposed)
    candidates = proposed.fetch('candidates')
    monetary = candidates.reject { |candidate| candidate['proposal_kind'] == 'quote_required' }
    contradictory_amounts?(monetary) || mixed_quote?(candidates, monetary) || monetary.pluck('currency').compact.uniq.many?
  end

  def contradictory_amounts?(monetary)
    monetary.group_by { |candidate| candidate['proposal_kind'] }
            .values.any? { |values| distinct_candidates(values).many? }
  end

  def mixed_quote?(candidates, monetary)
    monetary.any? && candidates.any? { |candidate| candidate['proposal_kind'] == 'quote_required' }
  end

  def published_conflict?(published, proposed)
    candidates = proposed.fetch('candidates')
    quote_conflict?(published, candidates) || candidates.any? do |candidate|
      candidate_conflict?(published, candidate)
    end
  end

  def quote_conflict?(published, candidates)
    !published['quote_required'] && candidates.any? { |candidate| candidate['proposal_kind'] == 'quote_required' }
  end

  def candidate_conflict?(published, candidate)
    return standard_conflict?(published, candidate) if candidate['proposal_kind'] == 'standard'
    return promotion_conflict?(published, candidate) if candidate['proposal_kind'] == 'promotion'

    false
  end

  def standard_conflict?(published, candidate)
    return true if published['quote_required'] || published['currency'] != candidate['currency']

    money_value(published['amount'], published['currency']) != money_value(candidate['amount'], candidate['currency'])
  end

  def promotion_conflict?(published, candidate)
    return true if published['currency'] != candidate['currency']
    return false if published['promotion_amount'].blank?

    money_value(published['promotion_amount'], published['currency']) !=
      money_value(candidate['amount'], candidate['currency'])
  end

  def money_value(amount, currency)
    AiLeadEmployee::OfferMoney.parse(amount, currency)
  end

  def distinct_candidates(candidates)
    candidates.uniq do |candidate|
      kind = candidate[:proposal_kind] || candidate['proposal_kind']
      currency = candidate[:currency] || candidate['currency']
      amount = candidate[:amount] || candidate['amount']
      minor_amount = money_value(amount, currency) unless kind == 'quote_required'
      [kind, currency, minor_amount]
    end
  end

  def source_digest
    Digest::SHA256.hexdigest(document.body.to_s)
  end
end
