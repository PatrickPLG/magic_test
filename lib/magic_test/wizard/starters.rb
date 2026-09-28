require "json"
require "time"

module MagicTest
  module Wizard
    # Built-in starting points (1.2 §5): one per Studiz role, seeded from the
    # real app's known-good setups and adjusted to what the specs actually use
    # (learned trait combinations and most-visited start pages). Only starters
    # whose factories and routes exist in this app are offered. Preflight
    # results are remembered in tmp/magic_test/starters_status.json so the
    # list can say "verified 2 hours ago" or flag a starter that failed.
    module Starters
      STATUS_PATH = "tmp/magic_test/starters_status.json"

      # Appendix A of the 1.2 brief: what works on the real app today.
      BUILT_IN = [
        {"id" => "provider_active_discount", "name" => "Provider with an active discount", "role_key" => "provider",
         "description" => "provider edits a discount", "signed_in" => "provider",
         "models" => [{"let" => "provider", "factory" => "provider", "traits" => %w[with_cvr]},
           {"let" => "discount", "factory" => "discount", "traits" => %w[active], "associations" => {"provider" => "provider"}}],
         "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}}},
        {"id" => "institution_leader", "name" => "Institution leader", "role_key" => "institution",
         "description" => "institution leader manages the events", "signed_in" => "institution",
         "models" => [{"let" => "institution", "factory" => "institution", "traits" => %w[with_user with_specialities]}],
         "start" => {"route" => "institution_events", "params" => {"institution_id" => "institution"}}},
        {"id" => "student_organisation", "name" => "Student organisation", "role_key" => "student_organisation",
         "description" => "student organisation manages its members", "signed_in" => "organisation",
         "models" => [{"let" => "organisation", "factory" => "student_organisation", "traits" => %w[with_user]}],
         "start" => {"route" => "student_organisation_student_organisation_memberships", "params" => {}}},
        {"id" => "student_verified", "name" => "Verified student", "role_key" => "student",
         "description" => "student edits the profile", "signed_in" => "student",
         "models" => [{"let" => "student", "factory" => "student", "traits" => %w[verified onboarded]}],
         "start" => {"route" => "edit_profile", "params" => {}}},
        {"id" => "admin_backoffice", "name" => "Admin in the backoffice", "role_key" => "admin",
         "description" => "admin works the leads", "signed_in" => "admin",
         "models" => [{"let" => "admin", "factory" => "admin", "traits" => []}],
         "start" => {"route" => "backoffice_leads", "params" => {}}},
        {"id" => "guest", "name" => "Guest (not signed in)", "role_key" => "guest",
         "description" => "guest reads the front page", "signed_in" => nil, "models" => [],
         "start" => {"route" => "root", "params" => {}}}
      ].freeze

      module_function

      # Starters this app can run, each with its plan, availability and last status.
      def list(catalogue)
        statuses = read_status(catalogue.root)
        BUILT_IN.map do |seed|
          plan = plan_for(seed, catalogue)
          missing = missing_parts(seed, catalogue)
          status = statuses[seed["id"]] || {}
          {"id" => seed["id"], "name" => seed["name"], "role_key" => seed["role_key"], "plan" => plan,
           "available" => missing.empty?, "missing" => missing,
           "verified_at" => status["verified_at"], "ok" => status["ok"], "message" => status["message"]}
        end
      end

      def find(id, catalogue)
        list(catalogue).find { |s| s["id"] == id.to_s } or raise Wizard::Error, "no starter called #{id.inspect}"
      end

      # The seed adjusted to the specs: the most common trait combination of
      # each factory when the specs use one, the role's most visited start page.
      def plan_for(seed, catalogue)
        learned = catalogue.learned
        models = seed["models"].map do |m|
          traits, files = learned.default_traits(m["factory"])
          m.merge("traits" => (files.positive? ? traits : m["traits"]).dup, "count" => 1, "associations" => (m["associations"] || {}).dup, "attributes" => {})
        end
        start = seed["start"].dup
        visited = learned.route_visits(seed["role_key"]).sort_by { |_r, n| -n }.map(&:first)
        best = visited.find { |r| catalogue.route(r) }
        if best && best != start["route"]
          route = catalogue.route(best)
          params = route.params.to_h { |p| [p, seed["start"]["params"][p] || param_default(p, models)] }
          start = {"route" => best, "params" => params} if params.values.none?(&:nil?)
        end
        {"description" => seed["description"], "target" => {"path" => "", "block" => nil}, "signed_in" => seed["signed_in"],
         "models" => models, "start" => start.merge("locale" => I18n.default_locale.to_s), "starter" => seed["id"]}
      end

      def param_default(part, models)
        base = part.to_s.sub(/_id\z/, "")
        models.find { |m| m["let"] == base || m["factory"] == base }&.fetch("let", nil)
      end

      def missing_parts(seed, catalogue)
        missing = seed["models"].reject { |m| catalogue.factory(m["factory"]) }.map { |m| "factory :#{m["factory"]}" }
        missing << "route #{seed["start"]["route"]}" unless catalogue.route(seed["start"]["route"])
        missing
      end

      def status_path(root)
        Pathname(root.to_s).join(STATUS_PATH)
      end

      def read_status(root)
        path = status_path(root)
        path.exist? ? JSON.parse(path.read) : {}
      rescue JSON::ParserError
        {}
      end

      # Called after a preflight of a plan that came from a starter.
      def record_status(root, id, ok:, message: nil)
        statuses = read_status(root)
        statuses[id.to_s] = {"verified_at" => Time.now.utc.iso8601, "ok" => ok, "message" => message}
        FileUtils.mkdir_p(status_path(root).dirname)
        status_path(root).write(JSON.pretty_generate(statuses))
        statuses[id.to_s]
      rescue => e
        MagicTest.logger.warn("magic_test wizard: could not write #{status_path(root)}: #{e.message}")
        nil
      end
    end
  end
end
