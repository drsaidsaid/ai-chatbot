# frozen_string_literal: true

class AiLeadEmployee::CommercialProposalReviewer
  def initialize(offer:, proposal:, reviewer:)
    @offer = offer
    @proposal = proposal
    @reviewer = reviewer
  end

  def approve!
    offer.class.transaction do
      lock_and_validate!
      current = offer.commercial_term
      validate_reconcilable!(current)
      saved = AiLeadEmployee::CommercialTerms.save_draft!(
        offer: offer,
        attributes: merged_terms(current),
        expected_version: current&.draft_version
      )
      record_review!(:approved)
      saved
    end
  end

  def reject!
    offer.class.transaction do
      lock_and_validate!
      record_review!(:rejected)
    end
  end

  private

  attr_reader :offer, :proposal, :reviewer

  def lock_and_validate!
    offer.lock!
    proposal.lock!
    return if proposal.pending? || proposal.conflict_review?

    raise ArgumentError, 'Commercial proposal was already reviewed'
  end

  def record_review!(status)
    proposal.update!(status: status, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def validate_reconcilable!(current)
    candidates = Array(proposal.proposed_terms['candidates'])
    raise ArgumentError, 'Resolve contradictory commercial facts before approval' if contradictory?

    currencies = candidates.filter_map { |candidate| candidate['currency'] }.uniq
    raise ArgumentError, 'Resolve conflicting currencies before approval' if currencies.many?

    validate_currency_change!(current, currencies.first, candidates)
  end

  def contradictory?
    proposal.conflict_details['reason'].to_s.include?('contradictory')
  end

  def validate_currency_change!(current, proposed_currency, candidates)
    return if proposed_currency.blank? || current.blank?

    base = current_terms(current)
    return unless currency_changes?(base, proposed_currency)
    return unless approval_retains_existing_money?(base, candidates)

    raise ArgumentError, 'Resolve the currency change for existing commercial amounts before approval'
  end

  def current_terms(current)
    current.draft_payload || current.published_payload || {}
  end

  def currency_changes?(base, proposed_currency)
    base['currency'].present? && base['currency'] != proposed_currency
  end

  def approval_retains_existing_money?(base, candidates)
    kinds = candidates.pluck('proposal_kind')
    (base['amount'].present? && kinds.exclude?('standard')) ||
      (base['promotion_amount'].present? && kinds.exclude?('promotion'))
  end

  def merged_terms(current)
    proposed = proposal.proposed_terms
    base = current&.draft_payload || current&.published_payload || default_terms(proposed)
    apply_proposed_terms(base, proposed).except('draft_version', 'revision', 'published_at')
  end

  def default_terms(proposed)
    {
      'currency' => proposed['currency'] || offer.currency, 'quote_required' => false, 'timezone' => 'UTC'
    }
  end

  def apply_proposed_terms(base, proposed)
    kinds = Array(proposed['proposal_kinds'].presence || proposed['proposal_kind'])
    terms = apply_standard_terms(base, proposed, kinds)
    terms = terms.merge('promotion_amount' => proposed['promotion_amount'], 'currency' => proposed['currency']) if kinds.include?('promotion')
    kinds.include?('quote_required') ? terms.merge('quote_required' => true, 'amount' => nil) : terms
  end

  def apply_standard_terms(base, proposed, kinds)
    return base unless kinds.include?('standard')

    base.merge('amount' => proposed['amount'], 'currency' => proposed['currency'], 'quote_required' => false)
  end
end
