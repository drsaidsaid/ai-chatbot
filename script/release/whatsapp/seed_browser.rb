# Only an empty, disposable browser database may use this fixture.
database = ActiveRecord::Base.connection_db_config.database
abort 'Use the R03 browser test database' unless Rails.env.test? && database == 'ale_release_r03_browser'
abort 'Existing records are never replaced' if Account.exists? || User.exists?
ConfigLoader.new.process
account = Account.create!(name: 'R03 Synthetic Business', locale: 'en')
user = User.new(name: 'Release Operator', email: 'release-operator@example.test', password: ENV.fetch('RELEASE_ADMIN_PASSWORD'))
user.skip_confirmation!
user.save!
AccountUser.create!(account: account, user: user, role: :administrator)
puts "Synthetic administrator ready for account #{account.id}; no provider or launch approval configured."
