require "spec_helper"
require "active_support/all"
require "magic_test/event_log"
require "magic_test/request_log"

RSpec.describe(MagicTest::EventLog) do
  let(:log) { described_class.new }

  it "keeps events ordered by timestamp and sequence and dedupes by id" do
    expect(log.add({"id" => "b", "ts" => 20, "seq" => 2})).to(be(true))
    expect(log.add({"id" => "a", "ts" => 10, "seq" => 1})).to(be(true))
    expect(log.add({"id" => "a", "ts" => 10, "seq" => 1})).to(be(false))
    expect(log.all.map { |e| e["id"] }).to(eq(%w[a b]))
    expect(log.size).to(eq(2))
  end

  it "deletes and updates in place" do
    log.add_all([{"id" => "a", "ts" => 1}, {"id" => "b", "ts" => 2}])
    log.update("a") { |e| e["x"] = 1 }
    expect(log.find("a")["x"]).to(eq(1))
    log.delete("a")
    expect(log.all.map { |e| e["id"] }).to(eq(["b"]))
  end

  it "is safe under concurrent adds" do
    threads = 8.times.map { |t| Thread.new { 50.times { |i| log.add({"id" => "#{t}-#{i}", "ts" => i}) } } }
    threads.each(&:join)
    expect(log.size).to(eq(400))
  end
end

RSpec.describe(MagicTest::RequestLog) do
  let(:log) { described_class.new }

  def record(**attrs)
    MagicTest::RequestRecord.new(method: "GET", path: "/", status: 200, html: true, xhr: false, record_ids: [], **attrs)
  end

  it "numbers records, collects record ids and lists page loads" do
    log.add(record(path: "/a", record_ids: %w[1 2]))
    log.add(record(path: "/b", method: "POST", html: false, record_ids: %w[2 3]))
    log.add(record(path: "/c", xhr: true))
    expect(log.all.map(&:id)).to(eq([1, 2, 3]))
    expect(log.record_ids).to(eq(%w[1 2 3]))
    expect(log.html_page_loads.map(&:path)).to(eq(["/a"]))
    expect(log.since(1).map(&:path)).to(eq(["/b", "/c"]))
  end

  it "derives lazy-lookup scopes from rendered templates" do
    r = record(templates: ["institutions/events/index.html.haml", "institutions/events/_form.html.haml", "layouts/admin.html.haml"])
    expect(r.template_scopes).to(eq(%w[institutions.events.index institutions.events.form layouts.admin]))
  end
end
