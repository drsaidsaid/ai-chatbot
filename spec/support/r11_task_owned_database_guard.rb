# frozen_string_literal: true

class R11TaskOwnedDatabaseGuard
  NAME_PATTERN = /\Ar11_[a-z0-9_]+_(?:test|spec)\z/

  def self.authorized?(database_name:, allowed_database:, truncate_opt_in:)
    truncate_opt_in == '1' &&
      database_name == allowed_database &&
      database_name.match?(NAME_PATTERN)
  end

  def self.verify!(database_name:, allowed_database:, truncate_opt_in:)
    return true if authorized?(database_name: database_name, allowed_database: allowed_database,
                               truncate_opt_in: truncate_opt_in)

    raise "Refusing destructive fixture cleanup for database #{database_name.inspect}"
  end
end
