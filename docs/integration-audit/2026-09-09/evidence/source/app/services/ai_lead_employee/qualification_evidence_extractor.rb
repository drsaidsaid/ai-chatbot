# frozen_string_literal: true

class AiLeadEmployee::QualificationEvidenceExtractor
  def initialize(content)
    @content = content.to_s.downcase
  end

  def evidence
    extractors.filter_map do |signal, extractor|
      value = extractor.call(content)
      [signal, value] if value.present?
    end.to_h
  end

  private

  attr_reader :content

  def extractors
    {
      'business_type' => method(:extract_business_type),
      'problem' => method(:extract_problem),
      'lead_volume' => method(:extract_lead_volume),
      'urgency' => method(:extract_urgency),
      'budget' => method(:extract_budget),
      'decision_authority' => method(:extract_decision_authority),
      'contact_details' => method(:extract_contact_details)
    }
  end

  def extract_business_type(content)
    return 'agency' if content.match?(/\bagency\b/)
    return 'clinic' if content.match?(/\bclinic\b/)
    return 'salon' if content.match?(/\bsalon\b/)
    return 'business' if content.match?(/\bbusiness\b|\bcompany\b/)
  end

  def extract_problem(content)
    return content if content.match?(/\b(problem|struggl|need|help|fix|more leads|inquiries|sales)\b/)
  end

  def extract_lead_volume(content)
    match = content.match(/(\d+)\s*(leads|inquiries|messages|calls)/)
    match&.[](0)
  end

  def extract_urgency(content)
    return 'urgent' if content.match?(/\b(urgent|asap|now|immediately)\b/)
    return 'this week' if content.include?('this week')
    return 'this month' if content.include?('this month')
  end

  def extract_budget(content)
    money = content.match(/(?:\$|usd\s*)\s?(\d+[,\d]*)/i)
    return money[0] if money

    content.match(/\b\d+\s?(k|thousand)\b/)&.[](0)
  end

  def extract_decision_authority(content)
    return 'decision maker' if content.match?(/\b(i decide|i can decide|owner|founder|ceo|decision maker)\b/)
    return 'not decision maker' if content.match?(/\b(not the decision|need approval|ask my boss)\b/)
  end

  def extract_contact_details(content)
    email = content.match(URI::MailTo::EMAIL_REGEXP)
    return email[0] if email

    phone = content.match(/\+?\d[\d\s-]{7,}\d/)
    phone&.[](0)
  end
end
