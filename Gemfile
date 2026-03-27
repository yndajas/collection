source "https://rubygems.org"

gem "bootsnap", require: false
gem "devise", "~> 5.0"
gem "devise-two-factor", "~> 6.4"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.3"
gem "rqrcode", "~> 3.2"
gem "solid_cache"
gem "sqlite3", ">= 2.1"
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara", "~> 3.40"
  gem "cucumber-rails", "~> 4.0", require: false
  gem "database_cleaner-active_record", "~> 2.2"
  gem "rspec-rails", "~> 8.0"
  gem "simplecov", "~> 0.22.0", require: false
end
