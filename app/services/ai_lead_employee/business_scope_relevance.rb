# frozen_string_literal: true

require_relative 'information_request'

class AiLeadEmployee::BusinessScopeRelevance # rubocop:disable Metrics/ClassLength
  CONTEXT_KEY = 'ai_employee_scope_clarification'
  CONTEXT_TTL = 15.minutes
  STOP_WORDS = %w[
    a an and are can do does for from how i in is it my of on or our the this to we what with you your
    hii hiki jinsi kuhusu kwa la na ni unaweza ya yako
  ].freeze
  PERSONAL_PREFERENCE_PATTERNS = [
    /\b(?:your favorite|your favourite|your personal opinion)\b/,
    /\bdo you (?:believe|enjoy|feel|like|prefer|think)\b/,
    /\b(?:unapenda nini|maoni yako binafsi)\b/
  ].freeze
  EXTERNAL_FACT_PATTERNS = [
    /\AWhat is the capital of\s+[[:upper:]][[:alnum:]'-]*/i,
    /\AWhat is my pulse\??\z/i
  ].freeze
  EXTERNAL_SUBJECT_PATTERNS = [
    /\AHow much does\s+(?<subject>.+?)\s+cost\??\z/i,
    /\AWhat does\s+(?<subject>.+?)\s+cost\??\z/i,
    /\AWhat is the (?:price|refund policy) of\s+(?<subject>.+?)\??\z/i,
    /\AWho is the instructor of\s+(?<subject>.+?)\??\z/i
  ].freeze

  def initialize(account:, message:, offer: nil, conversation: nil, incoming_message: nil)
    @account = account
    @message = message.to_s
    @offer = offer
    @conversation = conversation
    @incoming_message = incoming_message
  end

  def clearly_outside_scope?
    disposition == :unrelated
  end

  def ambiguous?
    disposition == :ambiguous
  end

  def relevant?
    disposition == :relevant
  end

  def authoritative_scope_match?
    return false if external_fact_question?

    approved_scope_match? || configured_scope_match? || established_subject_match?
  end

  def addressed_authoritative_scope_match?
    approved_scope_match? || addressed_configured_name_match? || specific_configured_name_match?
  end

  def consumes_clarification?
    disposition
    @consumes_clarification == true
  end

  def resolved_question
    disposition
    @resolved_question
  end

  def resolved_message_id
    disposition
    @resolved_message_id
  end

  def resolved_language
    disposition
    @resolved_language
  end

  def reclarification_required?
    disposition
    @reclarification_required == true
  end

  private

  attr_reader :account, :message, :offer, :conversation, :incoming_message

  def informational_question?
    AiLeadEmployee::InformationRequest.call(message)
  end

  def disposition
    return @disposition if defined?(@disposition)

    @disposition = resolve_pending_clarification || initial_disposition
  end

  def initial_disposition
    return :relevant unless informational_question?
    return :relevant if approved_scope_match?
    return :unrelated if external_fact_question?
    return :relevant if configured_scope_match?
    return :unrelated if definitely_unrelated?
    return :relevant if established_subject_match?

    :ambiguous
  end

  def resolve_pending_clarification
    context = pending_clarification
    return unless context

    @consumes_clarification = true
    resolve_pending_response(context)
  end

  def resolve_pending_response(context)
    followup = AiLeadEmployee::InformationRequest.substantive_followup(message)
    return resolve_new_question(followup) if followup.present?

    explicit_resolution = resolve_explicit_scope(context)
    return explicit_resolution if explicit_resolution
    return resolve_pending_question(context) if substantive_information_request?
    return resolve_confirmation(context) if scope_confirmation?

    :unrelated
  end

  def resolve_new_question(question)
    @resolved_question = question
    @resolved_message_id = incoming_message&.id
    @resolved_language = AiLeadEmployee::LanguageDetector.detect(question)
    relevance = self.class.new(
      account: account, message: question, offer: offer, conversation: conversation, incoming_message: incoming_message
    )
    relevance.send(:initial_disposition)
  end

  def resolve_explicit_scope(context)
    return resolve_confirmation(context) if scope_polarity == :confirmation
    return :unrelated if scope_polarity == :denial
    return reclarify(context) if scope_polarity == :uncertain
  end

  def substantive_information_request?
    informational_question? && !affirmative_acknowledgment?
  end

  def resolve_confirmation(context)
    restore_pending_question(context)
    return :relevant if captured_offer_current?(context)

    @reclarification_required = true
    :ambiguous
  end

  def reclarify(context)
    restore_pending_question(context)
    @reclarification_required = true
    :ambiguous
  end

  def resolve_pending_question(context)
    return :unrelated if normalized_message == normalize(context['question'])

    initial_disposition
  end

  def restore_pending_question(context)
    @resolved_question = context['question']
    @resolved_message_id = context['message_id']
    @resolved_language = context['language']&.to_sym
  end

  def captured_offer_current?(context)
    context['offer_id'] == offer&.id && context['offer_configuration_version'] == offer&.configuration_version
  end

  def pending_clarification
    context = conversation&.additional_attributes&.[](CONTEXT_KEY)
    return unless context.is_a?(Hash)

    return context if valid_pending_clarification?(context)

    consume_invalid_context_if_later(context)
    nil
  rescue ArgumentError, TypeError
    nil
  end

  def consume_invalid_context_if_later(context)
    @consumes_clarification = true if incoming_message&.id.to_i > context['message_id'].to_i
  end

  def valid_pending_clarification?(context)
    context.is_a?(Hash) &&
      incoming_message&.id.to_i > context['message_id'].to_i &&
      Time.zone.parse(context['expires_at'].to_s) > Time.current &&
      previous_public_message_id == context['clarification_message_id'].to_i
  end

  def previous_public_message_id
    Message.where(conversation_id: conversation.id, private: false,
                  message_type: [Message.message_types[:incoming], Message.message_types[:outgoing]])
           .where('messages.id < ?', incoming_message.id).reorder(id: :desc).pick(:id)
  end

  def scope_confirmation?
    return true if affirmative_acknowledgment?
    return true if normalized_message.match?(
      /\b(?:your|this|the) (?:business|company|course|offer|product|program|programme|service)\b/
    )
    return true if normalized_message.match?(/\b(?:biashara hii|huduma hii|kozi hii|ofa hii)\b/)

    configured_names.any? { |name| normalized_message.match?(/\b#{Regexp.escape(normalize(name))}\b/) }
  end

  def affirmative_acknowledgment?
    normalized_message.match?(/\A(?:yes|okay|sure|correct|exactly|indeed|ndiyo|ndio|sawa|naam|ndivyo)\b/) ||
      normalized_message.match?(/\A(?:that s right|please do|you got it)\b/)
  end

  def scope_polarity
    events = polarity_events(denial_patterns, :denial) +
             polarity_events(correction_patterns, :confirmation) +
             polarity_events(affirmation_patterns, :confirmation) +
             polarity_events([uncertainty_pattern], :uncertain)
    latest = events.max_by(&:first)
    return :uncertain if latest&.last == :confirmation && uncertainty_governs_correction?(events)

    latest&.last
  end

  def uncertainty_governs_correction?(events)
    uncertainty = last_event(events, :uncertain)
    correction = last_event(events, :confirmation)
    return false unless uncertainty && correction && uncertainty.first < correction.first

    contrast_absent_between?(uncertainty.first, correction.first)
  end

  def last_event(events, polarity)
    events.select { |(_, event_polarity)| event_polarity == polarity }.max_by(&:first)
  end

  def contrast_absent_between?(first, last)
    intervening_text = normalized_message[first...last]
    intervening_text.exclude?(' but ') && intervening_text.exclude?(' lakini ')
  end

  def polarity_events(patterns, polarity)
    patterns.flat_map do |pattern|
      normalized_message.to_enum(:scan, pattern).map { [Regexp.last_match.begin(0), polarity] }
    end
  end

  def denial_patterns
    [
      /\b(?:no|hapana)\z/,
      /\b(?:(?:do not|don t) mean|not asking about|not about|not referring to) (?:this |your |the )?#{scope_noun_pattern}\b/,
      /\b(?:sio|si) kuhusu #{swahili_scope_noun_pattern}\b/,
      /\bsimaanishi #{swahili_scope_noun_pattern}\b/,
      *configured_names.map { |name| /\bnot (?:about )?#{Regexp.escape(normalize(name))}\b/ }
    ]
  end

  def correction_patterns
    configured_names.map do |name|
      /\b(?:i mean|namaanisha) (?:the |this )?#{Regexp.escape(normalize(name))}(?: (?:offer|course|product|service|ofa|kozi|huduma))?\b/
    end
  end

  def affirmation_patterns
    [/\b(?:yes|okay|sure|correct|exactly|indeed|ndiyo|ndio|sawa|naam|ndivyo)\z/]
  end

  def uncertainty_pattern
    /\b(?:maybe|perhaps|not sure|i am not sure|i m not sure|i think so|labda|sijui)\b/
  end

  def scope_noun_pattern
    '(?:business|company|course|offer|product|program|programme|service)'
  end

  def swahili_scope_noun_pattern
    '(?:biashara|huduma|kozi|ofa)(?: hii)?'
  end

  def established_subject_match?
    return false unless offer && conversation && incoming_message

    recent_offer_contexts.any? { |content| contextual_reference?(content) }
  end

  def recent_offer_contexts
    conversation.messages.where(message_type: Message.message_types[:outgoing], private: false)
                .where('id < ? AND created_at >= ?', incoming_message.id, CONTEXT_TTL.ago)
                .order(id: :desc).limit(6).filter_map do |candidate|
      employee = candidate.additional_attributes['ai_lead_employee']
      candidate.content if employee&.dig('offer_context', 'offer_id') == offer.id
    end
  end

  def contextual_reference?(content)
    overlap = significant_tokens(message) & significant_tokens(content)
    overlap.present? || normalized_message.split.intersect?(%w[it that this there these those])
  end

  def definitely_unrelated?
    PERSONAL_PREFERENCE_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
  end

  def external_fact_question?
    EXTERNAL_FACT_PATTERNS.any? { |pattern| message.strip.match?(pattern) } || external_subject_unconfigured?
  end

  def external_subject_unconfigured?
    match = EXTERNAL_SUBJECT_PATTERNS.filter_map { |pattern| message.strip.match(pattern) }.first
    return false unless match

    configured_names.none? { |name| normalize(name) == normalize(match[:subject]) }
  end

  def configured_scope_match?
    configured_names.any? { |name| normalized_message.match?(/\b#{Regexp.escape(normalize(name))}\b/) } ||
      addressed_configured_name_match? ||
      scope_match?(configured_scope_texts)
  end

  def addressed_configured_name_match?
    return false unless normalized_message.split.intersect?(%w[your this])

    configured_names.any? { |name| significant_tokens(message).intersect?(significant_tokens(name)) }
  end

  def specific_configured_name_match?
    configured_names.any? do |name|
      normalized_name = normalize(name)
      significant_tokens(normalized_name).size >= 2 && normalized_message.match?(/\b#{Regexp.escape(normalized_name)}\b/)
    end
  end

  def approved_scope_match?
    scope_match?(approved_scope_texts)
  end

  def scope_match?(texts)
    question_tokens = significant_tokens(message)
    return false if question_tokens.empty?

    texts.any? do |text|
      overlap = question_tokens & significant_tokens(text)
      overlap.size >= [2, question_tokens.size].min
    end
  end

  def configured_scope_texts
    offers = offer ? [offer] : account.qualification_offers.enabled_in_order.to_a
    offers.map { |candidate| candidate.configuration.to_json }
  end

  def configured_names
    offers = offer ? [offer] : account.qualification_offers.enabled_in_order.to_a
    [account.name, account.settings&.dig('ai_lead_employee', 'default_offer'), *offers.map(&:name)].compact_blank
  end

  def approved_scope_texts
    @approved_scope_texts ||= AiLeadEmployee::KnowledgeAnswerService.new(
      account: account,
      question: message,
      offer: offer,
      language: AiLeadEmployee::LanguageDetector.detect(message)
    ).approved_scope_texts
  end

  def significant_tokens(value)
    normalize(value).split.reject { |token| token.length < 3 || STOP_WORDS.include?(token) }.uniq
  end

  def normalized_message
    @normalized_message ||= normalize(message)
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^[:alnum:]\s]/, ' ').squish
  end
end
