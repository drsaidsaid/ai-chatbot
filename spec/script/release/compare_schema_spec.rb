# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'Release schema comparison' do # rubocop:disable RSpec/DescribeClass -- executable CLI boundary
  let(:schema) do
    <<~RUBY
      ActiveRecord::Schema[7.2].define(version: 2026_09_09_000100) do
        create_table "examples", force: :cascade do |t|
          t.string "name", null: false
          t.integer "priority", default: 0
          t.index ["name", "priority"], unique: true
        end
      end
    RUBY
  end

  def compare(first, second)
    Dir.mktmpdir('release-schema-spec') do |dir|
      paths = %w[first.rb second.rb].map { |name| File.join(dir, name) }
      File.write(paths.first, first)
      File.write(paths.last, second)
      Open3.capture3(RbConfig.ruby, File.expand_path('../../../script/release/compare_schema.rb', __dir__), *paths).last
    end
  end

  it 'accepts identical definitions with different physical column order' do
    reordered = schema.sub(/(    t.string[^\n]+\n)(    t.integer[^\n]+\n)/, '\2\1')
    expect(compare(schema, reordered)).to be_success
  end

  it 'rejects changed defaults, nullability, index order, or migration version' do
    variants = [schema.sub('default: 0', 'default: 1'), schema.sub('null: false', 'null: true'),
                schema.sub('["name", "priority"]', '["priority", "name"]'), schema.sub('000100', '000200')]
    variants.each { |variant| expect(compare(schema, variant)).not_to be_success }
  end
end
