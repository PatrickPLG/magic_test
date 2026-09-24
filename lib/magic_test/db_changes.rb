module MagicTest
  # Collects INSERT/UPDATE/DELETE statements per request from
  # `sql.active_record` and maps tables to models (including namespaced ones
  # such as Events::Event) to suggest count/attribute expectations.
  class DbChanges
    IGNORED_TABLES = %w[schema_migrations ar_internal_metadata sessions active_storage_blobs active_storage_attachments].freeze
    STATEMENT = /\A\s*(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+[`"]?([A-Za-z0-9_]+)[`"]?/i

    Change = Struct.new(:operation, :table, :model, :count)

    class << self
      def parse(sql)
        m = STATEMENT.match(sql.to_s)
        return nil unless m
        op = if m[1].upcase.start_with?("INSERT")
          :insert
        else
          (m[1].upcase.start_with?("UPDATE") ? :update : :delete)
        end
        [op, m[2]]
      end

      def model_for(table)
        return nil if IGNORED_TABLES.include?(table)
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
