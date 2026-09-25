# Studiz: Flipper with a memory adapter in the test environment. The spec
# helpers reset it before every example (see spec/rails_helper.rb).
require "flipper"
require "flipper/adapters/memory"

Flipper.configure do |config|
  config.default { Flipper.new(Flipper::Adapters::Memory.new) }
end
