# frozen_string_literal: true

class AiLeadEmployee::QualificationContactExtractor
  def self.value(text)
    email = text.scan(%r{[a-z0-9.!#$%&'*+/=\?^_\x60{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}}i).find do |candidate|
      URI::MailTo::EMAIL_REGEXP.match?(candidate)
    end
    return email if email

    extract_phone(text)
  end

  def self.extract_phone(text)
    label = text.match(/\b(?:phone|telephone|mobile|whatsapp|simu|namba)\b(?:\s+(?:number|is|ni|yangu|at|me|on))*\s*[:=]?\s*/)
    phone = label&.post_match&.match(/\A\+?\d[\d\s()-]{7,}\d(?!\d)/)&.[](0)
    phone if phone && phone.delete('^0-9').length.between?(9, 15)
  end

  private_class_method :extract_phone
end
