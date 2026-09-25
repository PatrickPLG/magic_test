require "yaml"

module MagicTest
  module Wizard
    # What the wizard collects. Both front ends and `--plan plan.yml` produce
    # one of these; the validator, the code generator and the preflight
    # runner only ever see a Plan.
    class Plan
      class Model
        attr_accessor :let, :factory, :traits, :count, :associations, :attributes

        def initialize(let:, factory:, traits: [], count: 1, associations: {}, attributes: {})
          @let = let.to_s
          @factory = factory.to_s
          @traits = Array(traits).map(&:to_s)
          @count = (count || 1).to_i
          @associations = (associations || {}).to_h { |k, v| [k.to_s, v&.to_s] }
          @attributes = (attributes || {}).to_h { |k, v| [k.to_s, v] }
        end

        def to_h
          {"let" => let, "factory" => factory, "traits" => traits, "count" => count, "associations" => associations, "attributes" => attributes}
        end

        def self.from_h(h)
          h = (h || {}).transform_keys(&:to_s)
          new(let: h["let"], factory: h["factory"], traits: h["traits"], count: h["count"], associations: h["associations"], attributes: h["attributes"])
        end
      end

      Target = Struct.new(:path, :block) do
        def to_h
          {"path" => path, "block" => block}
        end
      end

      Start = Struct.new(:route, :params, :locale) do
        def to_h
          {"route" => route, "params" => params, "locale" => locale}
        end
      end

      class Extras
        VIEWPORTS = {"desktop" => [1200, 800], "tablet" => [820, 1180], "mobile" => [390, 844]}.freeze
        FIELDS = %i[flags travel_to viewport cookie_consent sidekiq_inline mail_assertion fixture_files].freeze
        attr_accessor(*FIELDS)

        def initialize(h = {})
          h = (h || {}).transform_keys(&:to_s)
          @flags = Array(h["flags"]).map { |f| f.is_a?(Hash) ? f.transform_keys(&:to_s) : {"name" => f.to_s} }
          @travel_to = h["travel_to"].presence&.to_s
          @viewport = h["viewport"].presence
          @cookie_consent = h.key?("cookie_consent") ? !!h["cookie_consent"] : true
          @sidekiq_inline = !!h["sidekiq_inline"]
          @mail_assertion = !!h["mail_assertion"]
          @fixture_files = Array(h["fixture_files"]).map(&:to_s)
        end

        def viewport_size
          case viewport
          when nil, "" then nil
          when Array then viewport.map(&:to_i)
          when Hash then [viewport["width"] || viewport[:width], viewport["height"] || viewport[:height]].map(&:to_i)
          else VIEWPORTS[viewport.to_s]
          end
        end

        def to_h
          {"flags" => flags, "travel_to" => travel_to, "viewport" => viewport, "cookie_consent" => cookie_consent,
           "sidekiq_inline" => sidekiq_inline, "mail_assertion" => mail_assertion, "fixture_files" => fixture_files}
        end
      end

      attr_accessor :description, :target, :signed_in, :models, :start, :extras

      def initialize(description: "", target: nil, signed_in: nil, models: [], start: nil, extras: nil)
        @description = description.to_s
        @target = target.is_a?(Target) ? target : Target.new(path: hash_get(target, "path"), block: hash_get(target, "block"))
        @signed_in = signed_in.presence&.to_s
        @models = models.map { |m| m.is_a?(Model) ? m : Model.from_h(m) }
        s = start.is_a?(Start) ? start.to_h : (start || {})
        s = s.transform_keys(&:to_s)
        @start = Start.new(route: s["route"].presence&.to_s, params: (s["params"] || {}).to_h { |k, v| [k.to_s, v&.to_s] }, locale: (s["locale"].presence || I18n.default_locale).to_s)
        @extras = extras.is_a?(Extras) ? extras : Extras.new(extras)
      end

      def guest?
        signed_in.nil?
      end

      def hash_get(hash, key)
        return nil unless hash.respond_to?(:key?)
        hash[key] || hash[key.to_sym]
      end
      private :hash_get

      def model(let)
        models.find { |m| m.let == let.to_s }
      end

      def signed_in_model
        signed_in && model(signed_in)
      end

      def to_h
        {"description" => description, "target" => target.to_h, "signed_in" => signed_in, "models" => models.map(&:to_h), "start" => start.to_h, "extras" => extras.to_h}
      end

      def to_yaml
        to_h.to_yaml
      end

      def self.from_h(h)
        h = (h || {}).transform_keys(&:to_s)
        new(description: h["description"], target: h["target"], signed_in: h["signed_in"], models: h["models"] || [], start: h["start"], extras: h["extras"])
      end

      def self.from_yaml(text)
        from_h(YAML.safe_load(text, permitted_classes: [Symbol, Time, Date], aliases: true) || {})
      end

      def self.load(path)
        from_yaml(File.read(path))
      end

      # A deep copy (the browser wizard edits a plan between preflights).
      def dup
        Plan.from_h(Marshal.load(Marshal.dump(to_h)))
      end
    end
  end
end
