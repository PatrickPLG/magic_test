require "rails_helper"
require "magic_test/session"

RSpec.describe(MagicTest::Middleware) do
  let(:session) { instance_double(MagicTest::Session, request_log: MagicTest::RequestLog.new) }

  before { allow(MagicTest).to(receive(:session).and_return(session)) }

  def call(app_response, env = {})
    app = ->(_env) { app_response }
    described_class.new(app).call(Rack::MockRequest.env_for("/udbydere/42/admin/rabatter/7", env))
  end

  it "injects before </head>, falls back to </body>, then to appending" do
    status, headers, body = call([200, {"Content-Type" => "text/html", "Content-Length" => "30"}, ["<html><head></head><body></body></html>"]])
    expect(status).to(eq(200))
    expect(body.first).to(eq("<html><head>#{described_class::SCRIPT_TAG}\n</head><body></body></html>"))
    expect(headers["Content-Length"]).to(eq(body.first.bytesize.to_s))
    _, _, body = call([200, {"Content-Type" => "text/html"}, ["<body>x</body>"]])
    expect(body.first).to(eq("<body>x#{described_class::SCRIPT_TAG}\n</body>"))
    _, _, body = call([200, {"Content-Type" => "text/html"}, ["fragment"]])
    expect(body.first).to(eq("fragment#{described_class::SCRIPT_TAG}"))
  end

  it "leaves redirects, non-HTML and XHR responses alone" do
    _, _, body = call([302, {"Content-Type" => "text/html", "Location" => "/x"}, ["<html><head></head></html>"]])
    expect(body.first).not_to(include("__magic_test"))
    _, _, body = call([200, {"Content-Type" => "application/json"}, ["{}"]])
    expect(body.first).to(eq("{}"))
    _, _, body = call([200, {"Content-Type" => "text/html"}, ["<head></head>"]], "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest")
    expect(body.first).to(eq("<head></head>"))
  end

  it "records path, params, status, redirect target, record ids and the Warden user" do
    user = double("user", id: 9, class: User, role_type: "Provider", role_id: 42)
    warden = double("warden", user: user)
    call([302, {"Content-Type" => "text/html", "Location" => "/udbydere/42/admin/rabatter"}, [""]],
      "warden" => warden, "action_dispatch.request.parameters" => {"discount" => {"name_da" => "Kaffe", "category_ids" => ["3", "4"]}, "controller" => "x", "action" => "y"},
      "REQUEST_METHOD" => "PATCH")
    record = session.request_log.last
    expect(record.method).to(eq("PATCH"))
    expect(record.path).to(eq("/udbydere/42/admin/rabatter/7"))
    expect(record.status).to(eq(302))
    expect(record.location).to(eq("/udbydere/42/admin/rabatter"))
    expect(record.record_ids).to(contain_exactly("42", "7", "3", "4"))
    expect(record.params).to(eq({"discount" => {"name_da" => "Kaffe", "category_ids" => ["3", "4"]}}))
    expect(record.user).to(eq({"class" => "User", "id" => 9, "role_type" => "Provider", "role_id" => 42}))
    expect(record.redirect?).to(be(true))
  end

  it "captures the flash from the session store and templates/SQL from notifications" do
    env = {"rack.session" => {"flash" => {"flashes" => {"notice" => "Rabatten er gemt"}}}}
    app = lambda do |_env|
      ActiveSupport::Notifications.instrument("render_template.action_view", identifier: "#{Rails.root}/app/views/providers/admin/discounts/index.html.haml") {}
      ActiveSupport::Notifications.instrument("sql.active_record", sql: 'UPDATE "discounts" SET "name_da" = ?') {}
      [200, {"Content-Type" => "text/html"}, ["<head></head>"]]
    end
    described_class.subscribe!
    described_class.new(app).call(Rack::MockRequest.env_for("/udbydere/42/admin/rabatter/7", env))
    record = session.request_log.last
    expect(record.flash).to(eq({"notice" => "Rabatten er gemt"}))
    expect(record.templates).to(eq(["providers/admin/discounts/index.html.haml"]))
    expect(record.template_scopes).to(eq(["providers.admin.discounts.index"]))
    expect(record.db_changes).to(eq([{operation: :update, table: "discounts", model: "Discount", count: 1}]))
  end

  it "skips its own endpoints and ignored paths" do
    app = ->(_env) { [200, {"Content-Type" => "text/html"}, ["<head></head>"]] }
    described_class.new(app).call(Rack::MockRequest.env_for("/__magic_test/state"))
    described_class.new(app).call(Rack::MockRequest.env_for("/live_support/ping"))
    expect(session.request_log.all).to(be_empty)
  end

  it "never raises out of the request cycle" do
    allow(session.request_log).to(receive(:add).and_raise("boom"))
    expect { call([200, {"Content-Type" => "text/html"}, ["<head></head>"]]) }.to(raise_error("boom"))
    allow(session.request_log).to(receive(:add).and_call_original)
    broken = ->(_env) { [200, {"Content-Type" => "text/html"}, ["<head></head>"]] }
    allow(MagicTest).to(receive(:session).and_return(session))
    env = Rack::MockRequest.env_for("/x", "warden" => Object.new) # warden without #user
    expect { described_class.new(broken).call(env) }.not_to(raise_error)
  end
end
