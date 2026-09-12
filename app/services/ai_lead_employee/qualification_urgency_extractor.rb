# frozen_string_literal: true

class AiLeadEmployee::QualificationUrgencyExtractor
  def initialize(answered_signal:)
    @answered_signal = answered_signal
  end

  def value(text)
    return 'not urgent' if denied_urgency?(text)
    return 'unknown' if unknown_about_urgency?(text)
    return 'urgent' if text.match?(/\b(?:urgent|asap|immediately|haraka)\b/)
    return unless timing_intent?(text)

    timed_urgency(text)
  end

  private

  attr_reader :answered_signal

  def unknown_about_urgency?(text)
    text.match?(AiLeadEmployee::QualificationEvidenceExtractor::UNKNOWN) && text.match?(/\b(?:when|start|urgent|lini|muda)\b/)
  end

  def timed_urgency(text)
    return 'urgent' if text.match?(/\b(?:now|today|tomorrow|leo|kesho)\b/)
    return 'this week' if text.match?(/\b(?:this week|wiki hii)\b/)
    return 'this month' if text.match?(/\b(?:this month|mwezi huu)\b/)
  end

  def denied_urgency?(text)
    return true if text.match?(/\bnot (?:ready|in a hurry|urgent|now)\b|\b(?:isn't|isnt) urgent\b|\bno (?:rush|urgency)\b/)
    return true if text.match?(/\b(?:next year|postponed|baadaye|mwakani)\b|\b(?:si|sio) (?:haraka|dharura)\b/)

    text.match?(Regexp.union(
                  /\b(?:sitaki|sipangi|sihitaji|siwezi|siko tayari)\b.*\b(?:kuanza|haraka|leo|kesho)\b/,
                  /\b(?:do not|don't|dont|cannot|can't|cant|not ready to|not going to)\b.{0,40}\b(?:start|begin)\b/
                ))
  end

  def timing_intent?(text)
    answered_signal == 'urgency' || text.match?(/\b(?:want|needs?|would like|ready|start|begin|solve|fix|nataka|nahitaji|kuanza)\b/)
  end
end
