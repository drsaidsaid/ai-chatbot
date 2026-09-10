# frozen_string_literal: true

AiLeadEmployee::AiProvider::Response = Struct.new(
  :id,
  :model,
  :content,
  :finish_reason,
  :input_tokens,
  :output_tokens,
  :total_tokens,
  :cost_usd,
  :configuration_version,
  keyword_init: true
)
