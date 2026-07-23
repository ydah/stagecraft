# frozen_string_literal: true

module Stagecraft
  class Color
    HEX_PATTERN = /\A#?([0-9a-f]{6})([0-9a-f]{2})?\z/i

    attr_reader :r, :g, :b, :a

    def initialize(value = 0.0, green = nil, blue = nil, alpha = 1.0)
      components = normalize(value, green, blue, alpha)
      @r, @g, @b, @a = components.map(&:to_f)
    end

    def self.coerce(value)
      value.is_a?(self) ? value : new(value)
    end

    def to_a
      [r, g, b, a]
    end

    def to_larb
      Larb::Color.new(r, g, b, a)
    end

    def ==(other)
      other.respond_to?(:to_a) && to_a == other.to_a
    end

    private

    def normalize(value, green, blue, alpha)
      return from_hex(value) if value.is_a?(String)
      return normalize_array(value) if value.respond_to?(:to_ary)
      return normalize_array(value.to_a) if green.nil? && value.respond_to?(:to_a)
      return [value, value, value, alpha] if green.nil? && blue.nil?

      [value, green, blue, alpha]
    end

    def from_hex(value)
      match = HEX_PATTERN.match(value)
      raise ArgumentError, "invalid color #{value.inspect}" unless match

      rgb = match[1].scan(/../).map { |part| part.to_i(16) / 255.0 }
      rgb << (match[2] ? match[2].to_i(16) / 255.0 : 1.0)
    end

    def normalize_array(value)
      values = value.to_a
      raise ArgumentError, "color requires 3 or 4 components" unless [3, 4].include?(values.length)

      values.length == 3 ? [*values, 1.0] : values
    end
  end
end
