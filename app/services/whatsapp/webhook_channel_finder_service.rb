# Resolves the WhatsApp channel for an inbound WhatsApp Cloud webhook. Meta's
# display_phone_number can arrive formatted or in a country-specific variant (e.g. Brazil
# omits the mobile 9, Argentina adds a digit after the country code), so we try the
# raw digits first and then a normalized fallback, accepting only a candidate whose
# phone_number_id matches.
class Whatsapp::WebhookChannelFinderService
  def initialize(display_phone_number:, phone_number_id:)
    @display_phone_number = display_phone_number
    @phone_number_id = phone_number_id
  end

  def perform
    candidates = phone_numbers.map { |number| Channel::Whatsapp.find_by(phone_number: number) }
    candidates.compact.find { |channel| matches?(channel) }
  end

  # Setup and health must prove the same identity that incoming callbacks route by.
  def matches?(channel)
    phone_numbers.include?(channel.phone_number) && channel.provider_config['phone_number_id'] == @phone_number_id
  end

  private

  def digits
    @digits ||= @display_phone_number.to_s.gsub(/[^0-9]/, '')
  end

  def phone_numbers
    return [] if digits.blank?

    normalizer = Whatsapp::PhoneNumberNormalizationService::NORMALIZERS
                 .lazy.map(&:new).find { |n| n.handles_country?(digits) }
    ["+#{digits}", ("+#{normalizer.normalize(digits)}" if normalizer)].compact.uniq
  end
end
