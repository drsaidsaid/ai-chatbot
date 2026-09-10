module Whatsapp::MessageEvidence
  RESERVED_KEYS = %w[
    external_echo whatsapp_delivery whatsapp_provider_status whatsapp_delivery_timestamp whatsapp_delivery_error_code
  ].map { |key| key.delete('_') }.freeze

  def self.without_client_evidence(attributes)
    attributes.to_h.reject { |key, _| RESERVED_KEYS.include?(normalized_key(key)) }
  end

  def self.normalized_key(key)
    # The Inbox's camelcase-keys conversion trims Unicode whitespace and folds
    # dots, hyphens, underscores and spaces. Reserve the whole equivalent key
    # family, including Unicode letters that uppercase to an ASCII boundary.
    key.to_s.gsub(/\A[[:space:]\uFEFF]+|[[:space:]\uFEFF]+\z/, '').gsub(/[_.\- ]/, '').upcase.downcase
  end
  private_class_method :normalized_key
end
