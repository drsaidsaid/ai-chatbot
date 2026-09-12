# frozen_string_literal: true

require 'uri'

class AiLeadEmployee::OfferProgressionService
  LINK_KINDS = %w[purchase_link appointment].freeze

  def initialize(offer:, qualification_result: nil)
    @offer = offer
    @qualification_result = qualification_result
  end

  def perform
    return if offer.blank?

    step = offer.next_step
    return if step['kind'] == 'answer_only'
    return configured_question if step['kind'] == 'sales_call'
    return link_reply(step) if LINK_KINDS.include?(step['kind'])

    step['prompt'].presence if step['kind'] == 'enquiry'
  end

  private

  attr_reader :offer, :qualification_result

  def configured_question
    return unless qualification_result&.qualification_mode == 'enabled'

    qualification_result.next_question.presence
  end

  def link_reply(step)
    url = approved_url(step['url'])
    return if url.blank?

    [step['prompt'].presence, url].compact.join(' ')
  end

  def approved_url(value)
    uri = URI.parse(value.to_s)
    value if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
