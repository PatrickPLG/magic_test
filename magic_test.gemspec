lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "magic_test/version"

Gem::Specification.new do |spec|
  spec.name = "magic_test"
  spec.version = MagicTest::VERSION
  spec.authors = ["Andrew Culver", "Adam Pallozzi", "Patrick Giørtz"]
  spec.email = ["andrew.culver@gmail.com", "adampallozzi@gmail.com", "pg@studiz.dk"]

  spec.summary = "Record-and-replay RSpec system-test generator for the Studiz Rails app."
  spec.description = "Click around a real Chrome window and get RSpec/Capybara system-test code " \
                     "that replays headless on the first run. Studiz-specific fork of magic_test."
  spec.homepage = "https://github.com/PatrickPLG/magic_test"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|docs|\.github)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "capybara", ">= 3.40"
  spec.add_dependency "cuprite", ">= 0.15"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "standard"
end
