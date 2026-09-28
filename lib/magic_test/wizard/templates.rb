require "yaml"

module MagicTest
  module Wizard
    # Saved plans (1.2 §5): "Save as template" writes spec/magic_test/templates/<name>.yml;
    # step 1 lists them, and `bin/magic new --template <name> "description"` skips to review.
    module Templates
      DIR = "spec/magic_test/templates"

      module_function

      def dir(root = Rails.root)
        Pathname(root.to_s).join(DIR)
      end

      # "Provider: active discount" → "provider_active_discount"
      def slug(name)
        s = name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
        raise Wizard::Error, "a template needs a name (letters or digits)" if s.empty?
        s
      end

      def path(name, root = Rails.root)
        dir(root).join("#{slug(name)}.yml")
      end

      # Saves the plan (without its description: every test gets its own) and returns the path.
      def save(plan, name, root = Rails.root)
        file = path(name, root)
        FileUtils.mkdir_p(file.dirname)
        hash = plan.to_h.merge("template" => name.to_s)
        file.write(YAML.dump(hash))
        file.to_s
      end

      def list(root = Rails.root)
        Dir[dir(root).join("*.yml").to_s].sort.map do |file|
          hash = YAML.safe_load_file(file, permitted_classes: [Symbol], aliases: true) || {}
          {"name" => hash["template"] || File.basename(file, ".yml"), "slug" => File.basename(file, ".yml"), "path" => file, "plan" => hash.except("template")}
        rescue Psych::SyntaxError => e
          {"name" => File.basename(file, ".yml"), "slug" => File.basename(file, ".yml"), "path" => file, "error" => e.message}
        end
      end

      def load(name, root = Rails.root)
        entry = list(root).find { |t| t["slug"] == slug(name) || t["name"] == name.to_s }
        raise Wizard::Error, "no template called #{name.inspect} in #{dir(root)} (have: #{list(root).map { |t| t["slug"] }.join(", ").presence || "none"})" unless entry
        raise Wizard::Error, "template #{name} is not valid YAML: #{entry["error"]}" if entry["error"]
        Plan.from_h(entry["plan"])
      end
    end
  end
end
