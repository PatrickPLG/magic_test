source "https://rubygems.org"

# Runtime dependencies live in magic_test.gemspec.
gemspec

# --- Studiz target stack (pinned; see docs/DECISIONS.md) ---------------------
gem "rails", "7.0.8"
gem "capybara", "3.40.0"
gem "cuprite", "0.15.1"
gem "ferrum", "0.15"
gem "rspec", "~> 3.12.0"
gem "rspec-rails", "~> 6.0"
gem "devise", "4.9.3"
gem "simple_form", "5.1.0"
gem "haml", "5.2.2"
gem "factory_bot_rails", "~> 6.2.0"
gem "route_translator", "~> 14.1"
gem "database_cleaner-active_record", "~> 2.1"
gem "kaminari", "~> 1.2"
gem "sqlite3", "~> 1.6"
gem "puma", "~> 6.4"

# Rails 7.0.8 + Ruby 3.3 needs concurrent-ruby < 1.3.5 (Logger constant).
gem "concurrent-ruby", "1.3.4"

# --- Tooling ------------------------------------------------------------------
gem "standard", ">= 1.40"
gem "rake", ">= 13.0"
gem "pry" # optional at runtime; present here to test the `open_console` command
