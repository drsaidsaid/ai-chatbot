# frozen_string_literal: true

class R11TaskOwnedDatabaseGuard
  NAME_PATTERN = /\Ar11_[a-z0-9_]+_(?:test|spec)\z/

  def self.verify!(database_name:, allowed_database:, truncate_opt_in:)
    authorized = truncate_opt_in == '1' &&
                 database_name == allowed_database &&
                 database_name.match?(NAME_PATTERN)
    return true if authorized

    raise "Refusing destructive fixture cleanup for database #{database_name.inspect}"
  end
end
