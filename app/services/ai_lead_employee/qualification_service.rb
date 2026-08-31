# frozen_string_literal: true

class AiLeadEmployee::QualificationService
  REQUIRED_HIGHLY_QUALIFIED_SIGNALS = %w[problem budget urgency decision_authority].freeze
  SIGNAL_WEIGHTS = {
    'name' => 0,
    'business_type' => 10,
    'problem' => 20,
    'lead_volume' => 10,
    'urgency' => 20,
    'budget' => 20,
    'decision_authority' => 20,
    'contact_details' => 10
  }.freeze
  DEFAULT_QUESTIONS = [
    ['name', 'What is your name?'],
    ['business_type', 'What type of business do you run?'],
    ['problem', 'What problem are you trying to solve right now?'],
    ['lead_volume', 'How many leads or inquiries do you handle each month?'],
    ['urgency', 'How soon do you want this solved?'],
    ['budget', 'What budget range have you set aside for this?'],
    ['decision_authority', 'Are you the person who decides on this purchase?'],
    ['contact_details', 'What is the best email or phone number for follow-up?']
  ].freeze

  Result = Struct.new(:qualification, :next_question, :new_evidence, :review_request_reason, keyword_init: true)

  def initialize(conversation:, incoming_message: nil)
    @conversation = conversation
    @incoming_message = incoming_message
    @account = conversation.account
    @contact = conversation.contact
  end

  def perform
    capture_name!
    new_evidence = extract_evidence!
    qualification = evaluate!

    Result.new(
      qualification: qualification,
      next_question: next_question_for(qualification.evidence_snapshot),
      new_evidence: new_evidence,
      review_request_reason: review_request_reason_for(qualification)
    )
  end

  def self.record_human_evidence!(contact:, user:, signal:, value:, conversation: nil)
    evidence = nil

    ActiveRecord::Base.transaction do
      evidence = create_human_evidence!(contact: contact, conversation: conversation, user: user, signal: signal, value: value)
      supersede_current_evidence!(contact: contact, signal: signal, replacement: evidence)
      AiLeadEmployee::QualificationEvidenceAudit.record!(
        contact: contact,
        conversation: conversation,
        user: user,
        signal: signal,
        value: value
      )
    end

    evidence
  end

  def self.create_human_evidence!(contact:, conversation:, user:, signal:, value:)
    QualificationEvidence.create!(
      account: contact.account,
      contact: contact,
      conversation: conversation,
      user: user,
      signal: signal,
      source: :human,
      value: { 'value' => value.to_s },
      observed_at: Time.current
    )
  end

  def self.next_question_for(account:, evidence_snapshot:)
    configured_question_pairs(account).find { |signal, _prompt| evidence_snapshot.exclude?(signal) }&.second
  end

  def self.configured_question_pairs(account)
    configured_questions = account.qualification_questions.enabled_in_order
    if configured_questions.exists?
      pairs = configured_questions.map { |question| [question.signal, question.prompt] }
      return pairs if pairs.any? { |signal, _prompt| signal == 'name' }

      return [DEFAULT_QUESTIONS.first, *pairs]
    end

    DEFAULT_QUESTIONS
  end

  def self.supersede_current_evidence!(contact:, signal:, replacement:)
    QualificationEvidence.current
                         .where(account: contact.account, contact: contact, signal: signal)
                         .where.not(id: replacement.id)
                         .find_each { |evidence| evidence.update!(superseded_at: Time.current, superseded_by: replacement) }
  end

  private

  attr_reader :account, :contact, :conversation, :incoming_message

  def capture_name!
    evidence = AiLeadEmployee::LeadNameCaptureService.new(
      account: account,
      contact: contact,
      conversation: conversation,
      incoming_message: incoming_message,
      name_prompt: questions.find { |signal, _prompt| signal == 'name' }&.second
    ).perform
    @current_evidence = nil if evidence.present?
  end

  def extract_evidence!
    evidence = AiLeadEmployee::PersistedQualificationEvidenceExtractor.new(
      account: account,
      contact: contact,
      incoming_message: incoming_message,
      evidence_snapshot: current_evidence
    ).perform
    @current_evidence = nil if evidence.present?
    evidence
  end

  def evaluate!
    snapshot = current_evidence
    missing = missing_signals(snapshot)
    score = score_for(snapshot)
    quality = quality_for(snapshot, missing, score)

    LeadQualification.find_or_initialize_by(account: account, contact: contact).tap do |qualification|
      qualification.assign_attributes(
        quality: quality,
        follow_up_state: follow_up_state_for(quality),
        score: score,
        reasons: reasons_for(snapshot, missing, quality),
        missing_signals: missing,
        evidence_snapshot: snapshot,
        configuration_version: configuration_version,
        last_evaluated_at: Time.current
      )
      qualification.save!
      qualification.record_decision!
    end
  end

  def current_evidence
    @current_evidence ||= AiLeadEmployee::QualificationEvidenceSnapshot.new(account: account, contact: contact).to_h
  end

  def missing_signals(snapshot)
    questions.map(&:first).reject { |signal| snapshot.key?(signal) }
  end

  def score_for(snapshot)
    snapshot.keys.sum { |signal| SIGNAL_WEIGHTS.fetch(signal, 0) }
  end

  def quality_for(snapshot, missing, score)
    return :unqualified if unqualified?(snapshot)
    return :highly_qualified if (REQUIRED_HIGHLY_QUALIFIED_SIGNALS - snapshot.keys).empty?
    return :unknown if snapshot.except('name').empty?
    return :qualified if score >= 60 && missing.exclude?('budget')

    :low_qualified
  end

  def follow_up_state_for(quality)
    return :human_review if quality.to_s == 'highly_qualified'
    return :nurture if %w[low_qualified qualified].include?(quality.to_s)

    :no_follow_up
  end

  def review_request_reason_for(qualification)
    'qualification_blocker' if qualification.unqualified?
  end

  def reasons_for(snapshot, missing, quality)
    reasons = snapshot.map { |signal, evidence| "#{signal.humanize}: #{evidence['value']}" }
    reasons << 'Required highly qualified signals are present' if quality.to_s == 'highly_qualified'
    reasons << "Missing #{missing.map(&:humanize).join(', ')}" if missing.present?
    reasons
  end

  def next_question_for(snapshot)
    self.class.next_question_for(account: account, evidence_snapshot: snapshot)
  end

  def questions
    self.class.configured_question_pairs(account)
  end

  def configuration_version
    account.settings.fetch('qualification_config_version', 1).to_i
  end

  def unqualified?(snapshot)
    authority_value = snapshot.dig('decision_authority', 'value').to_s
    return true if authority_value == 'not decision maker'

    AiLeadEmployee::QualificationBudgetClassifier.out_of_range?(
      account: account,
      budget_value: snapshot.dig('budget', 'value').to_s
    )
  end
end
