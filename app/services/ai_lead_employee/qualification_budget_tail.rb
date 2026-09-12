# frozen_string_literal: true

class AiLeadEmployee::QualificationBudgetTail
  FINANCIAL = Regexp.new(
    '\\b(?:budget|bajeti|money|funds?|loan|bank|financ\\w*|spend|pay|afford|pesa|mkopo|benki|kutumia|' \
    'kulipa)\\b'
  )
  AUTHORITY = Regexp.new(
    '\\A(?:(?:i|we) (?:am|are|do not|don\'t|cannot|can\'t|can|own|decide)\\b|mimi (?:ni|ndiye)\\b|ninaam' \
    'ua\\b|sifanyi\\b)'
  )
  VOLUME = Regexp.new(
    '\\A(?:(?:i|we) (?:handle|receive|get|manage)|ninapokea|tunapokea|nahudumia) \\d+\\s*(?:leads|inqu' \
    'iries|messages|calls|maulizo|ujumbe|wateja)(?: (?:a|per) (?:day|week|month))?[.!]*\\z'
  )
  URGENCY = Regexp.new(
    '\\A(?:(?:i|we) (?:want|need|would like) to (?:start|begin) (?:now|today|tomorrow|this week|this ' \
    'month)|(?:nataka|nahitaji|tunataka) kuanza (?:leo|kesho|wiki hii|mwezi huu))[.!]*\\z'
  )
  PROBLEM = Regexp.new(
    '\\A(?:(?:my|our) (?:problem|inquiries|leads|sales|responses|customers|replies)\\b|(?:i|we) (?:ne' \
    'ed|want) (?:more (?:leads|inquiries|customers)\\b|help (?:answering|responding to) (?:customer ' \
    ')?(?:messages|inquiries)\\b)|(?:i am|we are) not sure (?:what|which) problem\\b|(?:nahitaji|nata' \
    'ka) (?:wateja|maulizo|mauzo)\\b)'
  )
  CONTACT = Regexp.new(
    '\\A(?:(?:my|our) (?:phone|email|mobile|whatsapp)|(?:phone|email|simu|namba))\\b'
  )

  ANCHORS = [
    [AUTHORITY, :extract_decision_authority],
    [VOLUME, :extract_lead_volume],
    [URGENCY, :extract_urgency],
    [PROBLEM, :extract_problem],
    [CONTACT, :extract_contact_details]
  ].freeze

  def self.independent?(text)
    return false if text.match?(FINANCIAL)

    ANCHORS.any? { |pattern, extractor| text.match?(pattern) && yield(extractor).present? }
  end
end
