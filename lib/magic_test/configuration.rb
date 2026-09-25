module MagicTest
  # Session-wide knobs. Everything has a Studiz-appropriate default; the
  # toolbar can flip `i18n_keys` per session.
  class Configuration
    # Tables whose INSERT/UPDATE/DELETE never become a DB-change suggestion:
    # Rails bookkeeping, sessions, Active Storage, auditing (audited), Ahoy
    # analytics, Flipper and the live-support tables. Strings match a table
    # name exactly; Regexps match against it.
    DEFAULT_IGNORED_TABLES = (
      %w[schema_migrations ar_internal_metadata sessions active_storage_blobs active_storage_attachments
        audits ahoy_visits ahoy_events flipper_features flipper_gates] + [/\Alive_support_/]
    ).freeze

    attr_accessor :i18n_keys, :assertion_style, :locale, :fixture_files_dir,
      :ignored_request_paths, :window_size, :poll_interval_ms, :max_ancestor_depth,
      :command_timeout, :studiz_modals
    attr_reader :ignored_tables
    # Wizard (1.1): how a signed-in role record resolves to the Devise user.
    # Role class name => lambda(let_name) returning a Ruby expression string.
    attr_accessor :user_for_role, :wizard_driven_by, :login_paths

    def initialize
      @i18n_keys = true
      @assertion_style = :house # `expect(Model.count).to(eq(n))`; :change offers the block form first
      @locale = nil # defaults to the request locale (usually :da)
      @fixture_files_dir = "spec/fixtures/files"
      @ignored_request_paths = [%r{\A/__magic_test}, %r{\A/live_support}, %r{\A/cable}, %r{\A/assets}, %r{\A/packs}, %r{\A/vendor}, %r{\A/js/}, %r{\A/css/}, %r{\A/rails/active_storage}]
      @window_size = [1200, 800]
      @poll_interval_ms = 700
      @max_ancestor_depth = 8
      @command_timeout = 20
      @studiz_modals = %w[#ajax-modal #full-view-modal #image-cropper-modal]
      @ignored_tables = DEFAULT_IGNORED_TABLES.dup
      @user_for_role = {
        # Studiz: an institution signs in through its leader employee's user.
        "Institution" => ->(let) { "#{let}.employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader]).user" }
      }
      @wizard_driven_by = "driven_by(:cuprite)" # first line of the generated `before`; nil to omit
      @login_paths = %w[/users/sign_in /login] # a preflight landing here means "not signed in"
    end

    # The Ruby expression that turns the role let into a Devise user.
    def user_expression(role_class_name, let)
      resolver = user_for_role[role_class_name.to_s] || user_for_role[role_class_name.to_s.to_sym]
      resolver ? resolver.call(let.to_s) : "#{let}.user"
    end

    # Always merged with the defaults: `config.ignored_tables = %w[foo]` and
    # `config.ignored_tables << /\Areport_/` both keep the built-in list.
    def ignored_tables=(list)
      @ignored_tables = (DEFAULT_IGNORED_TABLES + Array(list)).uniq
    end

    def ignored_table?(table)
      ignored_tables.any? { |t| t.is_a?(Regexp) ? t.match?(table.to_s) : t.to_s == table.to_s }
    end
  end
end
