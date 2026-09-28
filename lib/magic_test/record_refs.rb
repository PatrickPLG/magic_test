module MagicTest
  # B7: let-based expressions for values that come from the example's records.
  # Built from the memoised lets (name => record, or name => [records]); used
  # by the locator picker so that an id like `discount-card-42` becomes
  # "#discount-card-#{discount.id}" and a link text equal to `discount.name_da`
  # is emitted as that expression instead of the literal factory data.
  class RecordRefs
    MIN_VALUE_LENGTH = 3
    SKIPPED_ATTRIBUTES = %w[id created_at updated_at encrypted_password password_digest authentication_token
      reset_password_token confirmation_token unlock_token remember_token].freeze

    def initialize(memoized = {})
      @records = {} # expression => record (as first seen)
      @attributes = {} # expression => attribute values when first seen
      @by_id = Hash.new { |h, k| h[k] = [] }
      @values = {} # attribute value => [expressions]
      add(memoized)
    end

    # Adds lets that are new to the map. Values are copied when a record is
    # first seen and never refreshed: the recorder reloads records to suggest
    # `expect(discount.reload.name_da)`, and a locator that was recorded before
    # that change must still read `discount.name_da`, the value the factory gave.
    def add(memoized)
      Hash(memoized).each do |name, value|
        if value.is_a?(Array)
          value.each_with_index { |v, i| add_record("#{name}[#{i}]", v) if record_like?(v) }
        elsif record_like?(value)
          add_record(name.to_s, value)
        end
      end
      self
    end

    def empty?
      @records.empty?
    end

    # The attribute values a let had when first seen (nil for an unknown let).
    def attributes_for(expr)
      @attributes[expr.to_s]
    end

    # Let expressions whose record has this id ("42" → ["discount"]).
    def lets_for_id(id)
      @by_id[id.to_s]
    end

    # "discount-card-42" → "discount-card-#{discount.id}", when exactly one
    # record can be meant: the one whose class or let name appears in the
    # value, else the only record with that id. nil when nothing or several.
    def interpolate_id(value)
      value = value.to_s
      numbers = value.scan(/\d+/).uniq.select { |n| @by_id.key?(n) }
      return nil if numbers.empty?
      result = value.dup
      numbers.each do |n|
        expr = pick_let(value, @by_id[n]) or return nil
        result = result.gsub(/(?<!\d)#{n}(?!\d)/) { "\#{#{expr}.id}" }
      end
      result
    end

    # "Kaffe 10%" → "discount.name_da" when exactly one record attribute has that value.
    def expression_for_value(text)
      exprs = @values[text.to_s]
      (exprs && exprs.size == 1) ? exprs.first : nil
    end

    # Expressions of record values contained in the text (longest first), for
    # the review comment when the text is more than one value.
    def values_contained_in(text)
      text = text.to_s
      @values.select { |val, exprs| exprs.size == 1 && text.include?(val) && text != val }
        .sort_by { |val, _| [text.index(val), -val.length] }
        .map { |_, exprs| exprs.first }
    end

    private

    def add_record(expr, record)
      return if @records.key?(expr)
      @records[expr] = record
      @by_id[record.id.to_s] << expr
      attrs = attributes_of(record)
      @attributes[expr] = attrs
      attrs.each do |attr, val|
        next unless val.is_a?(String) && val.strip.length >= MIN_VALUE_LENGTH && !val.match?(/\A[\d\s.,:-]*\z/)
        (@values[val] ||= []) << "#{expr}.#{attr}"
      end
    end

    def record_like?(value)
      value.respond_to?(:id) && !value.id.nil? && !value.is_a?(Hash)
    end

    def attributes_of(record)
      attrs = if record.respond_to?(:attributes)
        record.attributes
      elsif record.respond_to?(:to_h)
        record.to_h.transform_keys(&:to_s)
      else
        {}
      end
      attrs.reject { |k, _| SKIPPED_ATTRIBUTES.include?(k.to_s) }
    rescue
      {}
    end

    # The let whose class name or let name appears in the value ("discount"
    # in "discount-card-42"), else the only candidate.
    def pick_let(value, exprs)
      return exprs.first if exprs.size == 1
      words = value.downcase.scan(/[a-z]+/)
      named = exprs.select do |expr|
        rec = @records[expr]
        klass = rec.class.respond_to?(:model_name) ? rec.class.model_name.singular : rec.class.name.to_s.gsub(/([a-z\d])([A-Z])/, '\\1_\\2').downcase.tr(":", "_")
        tokens = [expr[/\A[a-z_]+/].to_s, klass.to_s].flat_map { |t| t.split("_") }.reject(&:empty?)
        tokens.any? { |t| words.include?(t) }
      end
      (named.size == 1) ? named.first : nil
    end

    EMPTY = new({})
  end
end
