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
    sh "npx --no-install eslint app/assets/javascripts/magic_test/src app/assets/javascripts/magic_test/wizard spec/js"
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

namespace :docs do
  desc "Regenerate the wizard screenshots (browser wizard driven headless)"
  task :wizard_screenshots do
    FileUtils.mkdir_p("docs/images")
    FileUtils.rm_rf("tmp/wizard_docs")
    target = File.expand_path("tmp/wizard_docs/spec/system/provider/renames_discount_spec.rb")
    sh({"MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1", "MAGIC_TEST_WIZARD" => "browser", "MAGIC_TEST_TOOLBAR" => "1",
        "MAGIC_TEST_WIZARD_SCRIPT" => File.expand_path("docs/screenshots/wizard_script.rb"),
        "MAGIC_TEST_SCRIPT" => File.expand_path("docs/screenshots/wizard_record_script.rb"),
        "MAGIC_TEST_UI_TARGET" => target, "MAGIC_TEST_WIZARD_TARGET" => target,
        "MAGIC_TEST_SCREENSHOT_DIR" => File.expand_path("docs/images"), "FIXTURE_APP_DB" => "db/wizard_docs.sqlite3"},
      "bin/rspec lib/magic_test/wizard/entry_spec.rb")
  end

  desc "Regenerate the README screenshots from the fixture app (headless Chrome)"
  task :screenshots do
    FileUtils.mkdir_p("tmp/screenshots")
    FileUtils.mkdir_p("docs/images")
    # A copy, because the recorder writes the recorded steps into the spec it runs.
    FileUtils.cp("docs/screenshots/screenshots_spec.rb", "tmp/screenshots/screenshots_spec.rb")
    sh({"MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1", "MAGIC_TEST_TOOLBAR" => "1",
        "MAGIC_TEST_SCRIPT" => File.expand_path("docs/screenshots/script.rb"),
        "MAGIC_TEST_SCREENSHOT_DIR" => File.expand_path("docs/images")},
      "bin/rspec tmp/screenshots/screenshots_spec.rb")
  end
end

task spec: ["spec:unit", "spec:recorder"]
task default: [:lint, :spec]
