# frozen_string_literal: true

class AiLeadEmployee::LeadExportBody
  CHUNK_SIZE = 16.kilobytes

  def initialize(artifact)
    @artifact = artifact
  end

  def each
    return enum_for(__method__) unless block_given?

    artifact.rewind
    while (chunk = artifact.read(CHUNK_SIZE))
      yield chunk
    end
  end

  private

  attr_reader :artifact
end
