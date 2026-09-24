require "magic_test/codegen/step"
require "magic_test/codegen/locator_picker"
require "magic_test/codegen/emitter"
require "magic_test/codegen/assertions"
require "magic_test/codegen/builder"

module MagicTest
  module Codegen
    # `I18n.t('key')`, with interpolations and, when the page was rendered in
    # a locale other than the default one, `locale: :en` (the replaying spec
    # runs in the default locale).
    def self.t_code(key, interpolations = {}, locale = nil)
      args = [RubyLiteral.string(key.to_s)]
      kwargs = (interpolations || {}).to_h.transform_keys(&:to_sym)
      kwargs[:locale] = locale.to_sym if locale && locale.to_sym != I18n.default_locale.to_sym
      args << RubyLiteral.kwargs(kwargs) if kwargs.any?
      "I18n.t(#{args.join(", ")})"
    end
  end
end
