# frozen_string_literal: true

class AiLeadEmployee::BusinessSetupProposalExtractor
  NEXT_STEP_PATTERNS = {
    'purchase_link' => /\b(purchase link|buy now|kiungo cha ununuzi|nunua)\b/i,
    'appointment' => /\b(appointment|book(?:ing)?|miadi)\b/i,
    'sales_call' => /\b(sales call|discovery call|simu ya mauzo)\b/i,
    'enquiry' => /\b(enquir(?:y|ies)|inquir(?:y|ies)|maulizo)\b/i
  }.freeze
  VAGUE_FIT_PATTERN = /\b(?:confirmed|approved|eligible|suitable)\s+fit\b|\bfit\s+(?:is\s+)?(?:confirmed|approved)\b/i
  NEGATED_REQUIREMENT_PATTERN = /\b(no\s+.+\s+(?:required|needed)|does\s+not\s+require|not\s+required|haihitaji|si\s+lazima)\b/i
  VAGUE_FIT_UNKNOWN = 'Add a lead-addressable qualification requirement; “confirmed fit” alone cannot be asked of a Lead.'
  COMPLEX_QUALIFICATION_UNKNOWN = 'Clarify the qualification alternatives as one lead-addressable condition before adding rules.'

  def initialize(offer:, body:, reviewed_configuration:, previous_proposal: nil)
    @offer = offer
    @body = body.to_s
    @reviewed_configuration = reviewed_configuration.to_h.deep_stringify_keys
    @previous_proposal = previous_proposal.to_h.deep_stringify_keys
  end

  def perform
    proposed_configuration = configuration
    {
      'facts' => approved_sentences.reject { |sentence| rule?(sentence) }.first(8),
      'rules' => qualification_rule_sentences.first(8),
      'unknowns' => unknowns(proposed_configuration),
      'qualification_clarification_required' => AiLeadEmployee::BusinessSetupQualificationProposal.any_complex?(sentences),
      'configuration' => proposed_configuration,
      'knowledge_body' => knowledge_body,
      'generated_question_keys' => generated_question_keys,
      'source_ownership' => source_ownership
    }
  end

  private

  attr_reader :offer, :body, :reviewed_configuration, :previous_proposal

  def sentences = @sentences ||= body.split(/(?<=[.!?])\s+|\n+/).map(&:strip).reject(&:blank?)

  def approved_sentences
    @approved_sentences ||= sentences.flat_map { |s| AiLeadEmployee::CommercialClaimClassifier.approved_clauses(s, offer_name: offer.name) }
  end

  def rule?(sentence)
    return false if no_qualification?(sentence) || negated_requirement?(sentence)
    return false if AiLeadEmployee::BusinessSetupQualificationProposal.explanatory_negation?(sentence)
    return true if AiLeadEmployee::BusinessSetupQualificationProposal.complex?(sentence)

    sentence.match?(/\b(must|require[sd]?|need(?:s|ed)?|only if|eligible|fit|qualification|ustahiki|lazima|hitaji)\b/i)
  end

  def qualification_rule_sentences
    approved_sentences.select do |sentence|
      rule?(sentence) && !vague_fit_rule?(sentence) && !AiLeadEmployee::BusinessSetupQualificationProposal.complex?(sentence)
    end
  end

  def no_qualification?(sentence = body) = sentence.match?(/\b(no qualification|without qualification|hakuna[^.!?]*ustahiki)\b/i)

  def vague_fit_rule?(sentence) = sentence.match?(VAGUE_FIT_PATTERN)

  def negated_requirement?(sentence) = sentence.match?(NEGATED_REQUIREMENT_PATTERN)

  def unknowns(proposed_configuration)
    [].tap do |items|
      append_price_unknown(items)
      append_next_step_unknowns(items, proposed_configuration)
      append_qualification_unknown(items, proposed_configuration)
      append_vague_fit_unknown(items)
      items << COMPLEX_QUALIFICATION_UNKNOWN if AiLeadEmployee::BusinessSetupQualificationProposal.any_complex?(sentences)
      append_ambiguous_commercial_unknown(items)
      items << 'The source names multiple possible next steps; choose one before publishing.' if inferred_next_steps.many?
      items << 'Add at least one non-price business fact that the AI can use.' if approved_sentences.empty?
    end
  end

  def append_vague_fit_unknown(items)
    items << VAGUE_FIT_UNKNOWN if vague_fit_rule_present?
  end

  def vague_fit_rule_present? = approved_sentences.any? { |sentence| rule?(sentence) && vague_fit_rule?(sentence) }

  def append_ambiguous_commercial_unknown(items)
    unresolved = sentences.flat_map { |sentence| AiLeadEmployee::CommercialClaimClassifier.clauses(sentence) }.any? do |clause|
      AiLeadEmployee::CommercialClaimClassifier.unresolved?(clause, offer_name: offer.name)
    end
    items << 'A monetary statement could not be safely assigned to this Offer; review it explicitly.' if unresolved
  end

  def append_price_unknown(items)
    result = AiLeadEmployee::OfferPricingResolver.new(account: offer.account, offer: offer).perform
    return if result.answered?

    items << 'A current price or quote-required policy is still needed; use the authoritative Prices and promotions editor.'
  end

  def append_next_step_unknowns(items, proposed_configuration)
    next_step = proposed_configuration['next_step'].to_h
    items << 'Choose what happens next: answer only, enquiry, purchase link, sales call, or appointment.' if next_step['kind'].blank?
    return unless next_step['kind'].in?(%w[purchase_link appointment]) && next_step['url'].blank?

    items << 'Add the approved link required by the selected next step.'
  end

  def append_qualification_unknown(items, proposed_configuration)
    return if AiLeadEmployee::Offer::QUALIFICATION_MODES.include?(proposed_configuration['qualification_mode'])

    items << 'Qualification is optional. Choose not configured, disabled, or enabled before adding fit requirements.'
  end

  def configuration
    proposed = configuration_without_previous_source_fields
    @generated_question_keys = []
    @source_ownership = { 'question_keys' => [], 'questions' => {}, 'rules' => {} }
    apply_next_step_proposal!(proposed)
    apply_qualification_proposal!(proposed)
    normalize_positions!(proposed)
    AiLeadEmployee::BusinessSetupProposalOwnership.record!(
      ownership: source_ownership, configuration: proposed, keys: generated_question_keys
    )
    proposed
  end

  def configuration_without_previous_source_fields
    proposed = reviewed_configuration.slice(
      'name', 'currency', 'enabled', 'version', 'qualification_mode', 'next_step', 'questions', 'budget_ranges', 'rules',
      'score_weights', 'score_thresholds'
    )
    previous_ownership = previous_proposal.fetch('source_ownership', {})
    AiLeadEmployee::BusinessSetupProposalOwnership.remove_unchanged_fields!(proposed, previous_ownership)
    reset_owned_value!(proposed, 'next_step', previous_ownership['next_step'])
    reset_owned_value!(proposed, 'qualification_mode', previous_ownership['qualification_mode'])
    proposed
  end

  def reset_owned_value!(proposed, field, ownership)
    return unless ownership.is_a?(Hash) && proposed[field] == ownership['value']

    proposed[field] = ownership['baseline'].deep_dup
  end

  def apply_next_step_proposal!(proposed)
    kind = inferred_next_step
    return unless kind

    baseline = proposed.fetch('next_step', {}).deep_dup
    proposed['next_step'] = proposed.fetch('next_step', {}).merge('kind' => kind)
    source_ownership['next_step'] = { 'baseline' => baseline, 'value' => proposed['next_step'].deep_dup }
  end

  def inferred_next_step = inferred_next_steps.one? ? inferred_next_steps.first : nil

  def inferred_next_steps
    @inferred_next_steps ||= sentences.reject { |sentence| negated_requirement?(sentence) }.flat_map do |sentence|
      NEXT_STEP_PATTERNS.filter_map { |kind, pattern| kind if sentence.match?(pattern) }
    end.uniq
  end

  def apply_qualification_proposal!(proposed)
    return record_owned_qualification_mode!(proposed, 'disabled') if no_qualification?
    return if qualification_rule_sentences.empty?

    record_owned_qualification_mode!(proposed, 'enabled')
    questions = proposed_questions(proposed)
    @generated_question_keys = questions.pluck('key')
    source_ownership['question_keys'] = generated_question_keys
    proposed['questions'] = Array(proposed['questions']) + questions
    proposed['rules'] = Array(proposed['rules']) + proposed_rules(proposed, questions)
  end

  def record_owned_qualification_mode!(proposed, value)
    baseline = proposed['qualification_mode']
    proposed['qualification_mode'] = value
    source_ownership['qualification_mode'] = { 'baseline' => baseline, 'value' => value }
  end

  def proposed_questions(proposed)
    existing_keys = Array(proposed['questions']).pluck('key')
    qualification_rule_sentences.each_with_index.filter_map do |sentence, index|
      question = AiLeadEmployee::BusinessSetupQualificationProposal.question(
        sentence: sentence, position: Array(proposed['questions']).length + index
      )
      next if existing_keys.include?(question['key'])

      existing_keys << question['key']
      question
    end
  end

  def proposed_rules(proposed, questions)
    position = Array(proposed['rules']).length
    existing_fields = Array(proposed['rules']).pluck('field')
    questions.each_with_index.filter_map do |question, index|
      next if existing_fields.include?(question['key'])

      existing_fields << question['key']
      {
        'kind' => 'requirement', 'dimension' => question['purpose'], 'field' => question['key'],
        'operator' => question['key'] == 'sales_call_agreement' ? 'eq' : 'positive',
        'value' => (true if question['key'] == 'sales_call_agreement'), 'priority' => position + index, 'enabled' => true
      }
    end
  end

  def generated_question_keys = @generated_question_keys || []

  def source_ownership = @source_ownership || { 'question_keys' => [], 'questions' => {}, 'rules' => {} }

  def knowledge_body
    approved_sentences.map { |sentence| sentence.sub(/[.!?]+\z/, '') }.join('. ')
  end

  def normalize_positions!(proposed)
    Array(proposed['questions']).each_with_index { |question, index| question['position'] = index }
    Array(proposed['rules']).each_with_index { |rule, index| rule['priority'] = index }
  end
end
