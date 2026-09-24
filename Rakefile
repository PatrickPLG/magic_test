require "bundler/gem_tasks"
require "rspec/core/rake_task"

# Two RSpec passes: one without MAGIC_TEST (unit, helpers, "injects nothing"
# proofs) and one with MAGIC_TEST=1 MAGIC_TEST_HEADLESS=1 for everything that
# records in the browser (audit, parity, golden flows).
namespace :spec do
  desc "Unit and helper specs (MAGIC_TEST unset)"
  task :unit do
    sh "bin/rspec --tag ~recorder"
  end

  desc "Recorder specs: audit, parity, golden flows (MAGIC_TEST=1, headless)"
  task :recorder do
    sh({"MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1"}, "bin/rspec --tag recorder")
  end
end

desc "Lint Ruby (standard) and JavaScript (eslint when available)"
task :lint do
  sh "bundle exec standardrb"
  if system("npx --no-install eslint --version > /dev/null 2>&1")
    sh "npx --no-install eslint app/assets/javascripts/magic_test/src spec/js"
  else
    puts "eslint not installed (npm ci); skipping JS lint"
  end
end

desc "Write the recorder bundle to dist/recorder.js (for inspection only; the engine serves it directly)"
task :bundle do
  require_relative "lib/magic_test/version"
  require_relative "lib/magic_test/recorder_bundle"
  FileUtils.mkdir_p("dist")
  MagicTest::RecorderBundle.write("dist/recorder.js")
  puts "wrote dist/recorder.js"
end

task spec: ["spec:unit", "spec:recorder"]
task default: [:lint, :spec]
