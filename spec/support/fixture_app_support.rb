module FixtureAppSupport
  CHROME_WRAPPER = File.expand_path("bin/chrome", __dir__)

  # Options passed to Capybara::Cuprite::Driver, mirroring Studiz's registration
  # (Appendix A) plus what this container needs to launch Chrome.
  CUPRITE_OPTIONS = {
    process_timeout: 30,
    timeout: 15,
    js_errors: true,
    inspector: ENV["INSPECTOR"] == "true",
    headless: !(ENV["MAGIC_TEST"].present? && ENV["MAGIC_TEST_HEADLESS"].blank?),
    pending_connection_errors: false,
    browser_path: CHROME_WRAPPER,
    browser_options: {"disable-dev-shm-usage" => nil, "disable-gpu" => nil}
  }.freeze
end

# Ferrum reads BROWSER_PATH for any driver registered without an explicit path
# (for example a plain `driven_by :cuprite` inside a spec).
ENV["BROWSER_PATH"] ||= FixtureAppSupport::CHROME_WRAPPER
