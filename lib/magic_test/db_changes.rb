module MagicTest
  # Collects INSERT/UPDATE/DELETE statements per request from
  # `sql.active_record` and maps tables to models (including namespaced ones
  # such as Events::Event) to suggest count/attribute expectations.
  class DbChanges
    # B8: the shapes every adapter emits. Postgres adds `$1` binds and RETURNING
    # (harmless), may schema-qualify the table ("public"."discounts"), and
    # Rails' query logs or marginalia may put a /* comment */ first; a CTE
    # (`WITH x AS (...) UPDATE ...`) precedes the statement.
    LEADING_COMMENT = %r{\A(?:\s*/\*.*?\*/)*\s*}m
    CTE = /\AWITH\s+.*?\)\s+(?=INSERT|UPDATE|DELETE)/im
    STATEMENT = /\A(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+((?:[`"]?[A-Za-z0-9_]+[`"]?\s*\.\s*)*[`"]?([A-Za-z0-9_]+)[`"]?)/i

    Change = Struct.new(:operation, :table, :model, :count)

    class << self
      def parse(sql)
        text = sql.to_s.sub(LEADING_COMMENT, "")
        text = text.sub(CTE, "") if text.match?(/\AWITH\b/i)
        m = STATEMENT.match(text)
        return nil unless m
        op = if m[1].upcase.start_with?("INSERT")
          :insert
        else
          (m[1].upcase.start_with?("UPDATE") ? :update : :delete)
        end
        [op, m[3]]
      end

      # Configurable in MagicTest.config.ignored_tables (merged with
      # Configuration::DEFAULT_IGNORED_TABLES).
      def ignored_table?(table)
        MagicTest.config.ignored_table?(table)
      end

      def model_for(table)
        return nil if ignored_table?(table)
        @models ||= {}
        @models[table] ||= begin
          eager_load!
          ActiveRecord::Base.descendants
            .reject { |m| m.abstract_class? || m.name.nil? || m.name.start_with?("HABTM_") }
            .select { |m| m.table_name == table }
            .min_by { |m| m.ancestors.count { |a| a < ActiveRecord::Base } } # base class over STI children
        end
      end

      def eager_load!
        return if @eager_loaded
        @eager_loaded = true
        Rails.application.eager_load! if defined?(Rails) && Rails.application
      rescue => e
        MagicTest.logger.warn("magic_test: eager_load failed: #{e.message}")
      end

      # Aggregates raw [op, table] pairs into Change structs with counts.
      def summarise(pairs)
        pairs.group_by { |op, table| [op, table] }.map do |(op, table), list|
          model = model_for(table)
          next if model.nil?
          Change.new(operation: op, table: table, model: model.name, count: list.size)
        end.compact
      end
    end
  end
end
