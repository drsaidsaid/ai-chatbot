# frozen_string_literal: true

AiLeadEmployee::AiProvider::Response = Struct.new(:id, :model, :content, :finish_reason, keyword_init: true)
