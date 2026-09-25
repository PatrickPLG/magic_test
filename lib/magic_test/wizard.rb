# The "new system test" wizard (1.1): one engine, two front ends.
require "magic_test/wizard/catalogue"
require "magic_test/wizard/plan"
require "magic_test/wizard/validator"
require "magic_test/wizard/spec_file"
require "magic_test/wizard/codegen"

module MagicTest
  module Wizard
    class Error < MagicTest::Error; end

    module_function

    # Absolute path for a plan target (relative paths are relative to the app root).
    def resolve_path(path, root: Rails.root)
      Pathname(path.to_s).absolute? ? path.to_s : Pathname(root).join(path.to_s).to_s
    end

    # Suggested file name from role and start page, Studiz style:
    # spec/system/provider/provider_edits_discount_spec.rb
    def suggest_path(role_class_name, description, start_route = nil)
      dir = role_class_name ? role_class_name.to_s.demodulize.underscore : "public"
      base = description.to_s.parameterize(separator: "_").presence || start_route.to_s.presence || "new"
      File.join("spec/system", dir, "#{base}_spec.rb")
    end
  end
end
