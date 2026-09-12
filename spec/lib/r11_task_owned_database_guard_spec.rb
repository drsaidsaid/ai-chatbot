# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/r11_task_owned_database_guard'

RSpec.describe R11TaskOwnedDatabaseGuard do
  it 'rejects the shared default database even when it is allowlisted and opted in' do
    expect do
      described_class.verify!(
        database_name: 'chatwoot_test',
        allowed_database: 'chatwoot_test',
        truncate_opt_in: '1'
      )
    end.to raise_error(RuntimeError, /Refusing destructive fixture cleanup/)
  end

  it 'accepts an explicitly opted-in R11 task-owned test database' do
    expect(
      described_class.verify!(
        database_name: 'r11_source_concurrency_test',
        allowed_database: 'r11_source_concurrency_test',
        truncate_opt_in: '1'
      )
    ).to be(true)
  end

  it 'reports whether destructive cleanup is authorized without raising' do
    expect(
      described_class.authorized?(
        database_name: 'chatwoot_test',
        allowed_database: 'chatwoot_test',
        truncate_opt_in: '1'
      )
    ).to be(false)
    expect(
      described_class.authorized?(
        database_name: 'r11_source_concurrency_test',
        allowed_database: 'r11_source_concurrency_test',
        truncate_opt_in: '1'
      )
    ).to be(true)
  end

  it 'rejects the R11 database without an explicit destructive-cleanup opt-in' do
    expect do
      described_class.verify!(
        database_name: 'r11_source_concurrency_test',
        allowed_database: 'r11_source_concurrency_test',
        truncate_opt_in: nil
      )
    end.to raise_error(RuntimeError, /Refusing destructive fixture cleanup/)
  end
end
