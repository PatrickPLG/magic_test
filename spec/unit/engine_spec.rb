require "rails_helper"
require "rack/test"

# The "gem-locked" contract: with MAGIC_TEST unset the gem injects nothing,
# mounts no routes and adds no middleware; helpers are still available.
RSpec.describe("MagicTest engine integration") do
  include Rack::Test::Methods

  def app
    Rails.application
  end

  context "when MAGIC_TEST is unset", :no_recorder do
    it "is disabled" do
      expect(MagicTest.enabled?).to(be(false))
    end

    it "adds no middleware and mounts no routes" do
      expect(Rails.application.middleware.map(&:name)).not_to(include("MagicTest::Middleware"))
      expect(Rails.application.routes.routes.map { |r| r.path.spec.to_s }).not_to(include(a_string_matching(/__magic_test/)))
    end

    it "injects nothing into HTML responses and serves no recorder script" do
      get "/vilkaar"
      expect(last_response.status).to(eq(200))
      expect(last_response.body).not_to(include("__magic_test"))
      expect { get "/__magic_test/recorder.js" }.to(raise_error(ActionController::RoutingError))
    end

    it "still includes MagicTest::Helpers into type: :system groups", type: :system do
      expect(self).to(respond_to(:magic_chosen_select, :magic_set_date, :magic_fill_trix, :magic_attach_image, :magic_within_modal, :magic_sign_in, :magic_test))
      expect(self.class.ancestors).not_to(include(MagicTest::Support))
    end

    it "makes magic_test a no-op" do
      klass = Class.new { include MagicTest::Helpers }
      expect(klass.new.magic_test).to(be_nil)
    end

    it "renders the legacy partial as nothing" do
      html = ApplicationController.render(inline: "<%= render 'magic_test/support' %>x")
      expect(html.strip).to(eq("x"))
    end
  end

  context "when MAGIC_TEST is set", :recorder do
    it "is enabled with the middleware and routes in place" do
      expect(MagicTest.enabled?).to(be(true))
      expect(Rails.application.middleware.map(&:name)).to(include("MagicTest::Middleware"))
      expect(Rails.application.routes.routes.map { |r| r.path.spec.to_s }).to(include("/__magic_test"))
    end

    it "injects one deferred script tag before </head> of every HTML page, including layouts without the partial" do
      %w[/vilkaar /forhaandsvisning-ramme /dobbelt].each do |path|
        get path
        expect(last_response.status).to(eq(200))
        expect(last_response.body.scan(MagicTest::Middleware::SCRIPT_TAG).size).to(eq(1), path)
        expect(last_response.body.index(MagicTest::Middleware::SCRIPT_TAG)).to(be < last_response.body.index("</head>"))
      end
    end

    it "does not inject into JSON, XHR or the recorder's own responses" do
      get "/live_support/ping"
      expect(last_response.body).not_to(include("__magic_test"))
      get "/vilkaar", {}, {"HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"}
      expect(last_response.body).not_to(include("__magic_test/recorder.js"))
      get "/__magic_test/recorder.js"
      expect(last_response.status).to(eq(200))
      expect(last_response.content_type).to(include("javascript"))
      expect(last_response.body).to(start_with("/* magic_test recorder"))
      expect(last_response.body).to(include("window.MagicTest = api"))
    end

    it "answers idle when no session is running and rejects events" do
      get "/__magic_test/config"
      expect(JSON.parse(last_response.body)).to(eq({"status" => "idle", "enabled" => true}))
      post "/__magic_test/events", {events: [{id: "x"}]}.to_json, {"CONTENT_TYPE" => "application/json"}
      expect(JSON.parse(last_response.body)["ok"]).to(be(false))
    end

    it "includes MagicTest::Support (flush/ok) into type: :system groups", type: :system do
      expect(self).to(respond_to(:flush, :ok))
    end

    it "keeps the Content-Length header consistent when injecting" do
      get "/vilkaar"
      if last_response.headers["Content-Length"]
        expect(last_response.headers["Content-Length"].to_i).to(eq(last_response.body.bytesize))
      end
    end
  end

  describe MagicTest::LegacyOverrideCheck do
    it "warns loudly when app/views/magic_test contains the old partials" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        FileUtils.mkdir_p(root.join("app/views/magic_test"))
        File.write(root.join("app/views/magic_test/_javascript_helpers.html"), "<script></script>")
        message = nil
        expect { message = described_class.run(root) }.to(output(/Delete the directory/).to_stderr)
        expect(message).to(include("git rm -r #{root.join("app/views/magic_test")}"))
      end
    end

    it "stays silent when the directory is absent" do
      Dir.mktmpdir do |dir|
        expect { described_class.run(Pathname.new(dir)) }.not_to(output.to_stderr)
      end
    end
  end

  describe MagicTest::CupriteDefaults, :recorder do
    it "forces a headed 1200x800 window under MAGIC_TEST unless MAGIC_TEST_HEADLESS is set" do
      driver_class = Class.new do
        attr_reader :options
        def initialize(app, options = {})
          @options = options
        end
      end
      driver_class.prepend(described_class)
      ENV["MAGIC_TEST_HEADLESS"] = nil
      d = driver_class.new(nil, {headless: true, process_timeout: 10})
      expect(d.options[:headless]).to(be(false))
      expect(d.options[:window_size]).to(eq([1200, 800]))
      expect(d.options[:process_timeout]).to(eq(30))
    ensure
      ENV["MAGIC_TEST_HEADLESS"] = "1"
    end

    it "keeps headless when MAGIC_TEST_HEADLESS is set" do
      driver_class = Class.new do
        attr_reader :options
        def initialize(app, options = {})
          @options = options
        end
      end
      driver_class.prepend(described_class)
      d = driver_class.new(nil, {headless: true, window_size: [800, 600]})
      expect(d.options[:headless]).to(be(true))
      expect(d.options[:window_size]).to(eq([800, 600]))
    end
  end
end
