# frozen_string_literal: true

class AiLeadEmployee::BusinessScopeRelevance
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
  EXTERNAL_NAMED_SUBJECT_PATTERNS = [
    /\AHow much does\s+[[:upper:]][[:alnum:]'-]*/,
    /\A(?:What|Which|Who) (?:is|are|was|were) the .+\b(?:of|in)\s+[[:upper:]][[:alnum:]'-]*/
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

  private

  attr_reader :account, :message, :offer, :conversation, :incoming_message

  def informational_question?
    message.include?('?') || normalized_message.match?(
      /\A(?:can|could|do|does|how|is|are|what|when|where|which|who|why|je|jinsi|lini|nini|wapi)\b/
    )
  end

  def disposition
    return @disposition if defined?(@disposition)

    @disposition = resolve_pending_clarification || initial_disposition
  end

  def initial_disposition
    return :relevant unless informational_question?
    return :relevant if approved_scope_match?
    return :unrelated if definitely_unrelated?
    return :relevant if configured_scope_match?
    return :relevant if established_subject_match?

    :ambiguous
  end

  def resolve_pending_clarification
    context = pending_clarification
    return unless context

    @consumes_clarification = true
    return :unrelated unless scope_confirmation?

    @resolved_question = context['question']
    @resolved_message_id = context['message_id']
    @resolved_language = context['language']&.to_sym
    :relevant
  end

  def pending_clarification
    context = conversation&.additional_attributes&.[](CONTEXT_KEY)
    return unless valid_pending_clarification?(context)

    context
  rescue ArgumentError, TypeError
    nil
  end

  def valid_pending_clarification?(context)
    context.is_a?(Hash) &&
      incoming_message&.id.to_i > context['message_id'].to_i &&
      Time.zone.parse(context['expires_at'].to_s) > Time.current &&
      previous_public_incoming_id == context['message_id'].to_i
  end

  def previous_public_incoming_id
    conversation.messages.where(message_type: Message.message_types[:incoming], private: false)
                .where('id < ?', incoming_message.id).order(id: :desc).pick(:id)
  end

  def scope_confirmation?
    return true if normalized_message.in?(%w[yes ndiyo ndio])
    return true if normalized_message.match?(
      /\b(?:your|this|the) (?:business|company|course|offer|product|program|programme|service)\b/
    )
    return true if normalized_message.match?(/\b(?:biashara hii|huduma hii|kozi hii|ofa hii)\b/)

    configured_names.any? { |name| normalized_message.match?(/\b#{Regexp.escape(normalize(name))}\b/) }
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

  def configured_scope_match?
    configured_names.any? { |name| normalized_message.match?(/\b#{Regexp.escape(normalize(name))}\b/) } ||
      scope_match?(configured_scope_texts)
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
