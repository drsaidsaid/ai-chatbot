# frozen_string_literal: true

require 'digest'

abort 'Usage: ruby script/release/compare_schema.rb FIRST_SCHEMA SECOND_SCHEMA' unless ARGV.length == 2

# PostgreSQL preserves physical column order. Compare complete Rails definitions
# while allowing only column/index declaration order inside a table to differ.
normalized = ARGV.map do |path|
  File.read(path).gsub(/(  create_table [^\n]+ do \|t\|\n)(.*?)(  end\n)/m) do
    opening, body, closing = Regexp.last_match.captures
    opening + body.lines.reject { |line| line.strip.empty? }.sort.join + closing
  end
end

abort 'Schema mismatch: inspect the two dumps; do not promote this release.' unless normalized.first == normalized.last

puts "Schemas match (column declaration order ignored): #{Digest::SHA256.hexdigest(normalized.first)}"
