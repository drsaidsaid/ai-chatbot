# frozen_string_literal: true

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
    /\AWhat is the capital of\s+[[:upper:]][[:alnum:]'-]*/i
  ].freeze
  EXTERNAL_NAMED_SUBJECT_PATTERNS = [/\AHow much does\s+[[:upper:]][[:alnum:]'-]*/i].freeze
  BUSINESS_INTEREST_PATTERNS = [/\bi am interested\b.*\b(?:start|begin)\b/].freeze

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
    return :relevant unless scope_evaluation_required?
    return :relevant if approved_scope_match?
    return :unrelated if external_fact_question?
    return :relevant if configured_scope_match?
    return :unrelated if definitely_unrelated?
    return :relevant if established_subject_match?

    :ambiguous
  end

  def scope_evaluation_required?
    informational_question? && !business_interest?
  end

  def resolve_pending_clarification
    context = pending_clarification
    return unless context

    @consumes_clarification = true
    return :unrelated if scope_denial?
    return resolve_pending_question(context) if substantive_information_request?
    return resolve_confirmation(context) if scope_confirmation?

    :unrelated
  end

  def substantive_information_request?
    informational_question? && !normalized_message.match?(/\A(?:yes|okay|ndiyo|ndio|sawa)\b/)
  end

  def resolve_confirmation(context)
    restore_pending_question(context)
    return :relevant if captured_offer_current?(context)

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
    return true if normalized_message.match?(/\A(?:yes|okay|ndiyo|ndio|sawa)\b/)
    return true if normalized_message.match?(
      /\b(?:your|this|the) (?:business|company|course|offer|product|program|programme|service)\b/
    )
    return true if normalized_message.match?(/\b(?:biashara hii|huduma hii|kozi hii|ofa hii)\b/)

    configured_names.any? { |name| normalized_message.match?(/\b#{Regexp.escape(normalize(name))}\b/) }
  end

  def scope_denial?
    normalized_message.in?(%w[no hapana]) ||
      normalized_message.match?(
        /\b(?:not asking about|not about) (?:this |your |the )?(?:business|company|course|offer|product|program|programme|service)\b/
      ) || normalized_message.match?(/\b(?:sio|si) kuhusu (?:biashara|huduma|kozi|ofa) hii\b/)
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
    PERSONAL_PREFERENCE_PATTERNS.any? { |pattern| normalized_message.match?(pattern) } ||
      EXTERNAL_NAMED_SUBJECT_PATTERNS.any? { |pattern| message.strip.match?(pattern) }
  end

  def business_interest?
    BUSINESS_INTEREST_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
  end

  def external_fact_question?
    EXTERNAL_FACT_PATTERNS.any? { |pattern| message.strip.match?(pattern) }
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
