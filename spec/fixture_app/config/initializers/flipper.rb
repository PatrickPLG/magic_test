# Studiz: Flipper with a memory adapter in the test environment. One adapter
# shared by every thread (Flipper.instance is thread-local, and the Capybara
# server runs in its own threads); the spec helpers empty it before every
# example (see spec/rails_helper.rb).
require "flipper"
require "flipper/adapters/memory"

FLIPPER_TEST_ADAPTER = Flipper::Adapters::Memory.new

Flipper.configure do |config|
  config.default { Flipper.new(FLIPPER_TEST_ADAPTER) }
end
