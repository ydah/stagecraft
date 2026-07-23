# frozen_string_literal: true

module Stagecraft
  module Materials
    class Base
      SIDES = %i[front back double].freeze
      BLENDS = %i[normal additive multiply].freeze
      ALPHA_MODES = %i[opaque mask blend].freeze

      attr_reader :version

      def initialize(transparent: false, opacity: 1.0, side: :front, depth_write: true,
                     depth_test: true, blend: :normal, alpha_mode: :opaque, alpha_cutoff: 0.5)
        @version = 0
        self.transparent = transparent
        self.opacity = opacity
        self.side = side
        self.depth_write = depth_write
        self.depth_test = depth_test
        self.blend = blend
        self.alpha_mode = alpha_mode
        self.alpha_cutoff = alpha_cutoff
      end

      def self.versioned_attribute(name, coerce: nil, validate: nil)
        attr_reader name
        define_method(:"#{name}=") do |value|
          next_value = coerce ? coerce.call(value) : value
          if validate && !validate.call(next_value)
            raise ArgumentError, "invalid #{name}: #{value.inspect}"
          end
          return next_value if instance_variable_defined?(:"@#{name}") &&
                               instance_variable_get(:"@#{name}") == next_value

          instance_variable_set(:"@#{name}", next_value)
          @version += 1
          next_value
        end
      end

      versioned_attribute :transparent, coerce: ->(value) { !!value }
      versioned_attribute :opacity, coerce: ->(value) { Float(value) },
                                      validate: ->(value) { value.between?(0.0, 1.0) }
      versioned_attribute :side, coerce: :to_sym.to_proc, validate: ->(value) { SIDES.include?(value) }
      versioned_attribute :depth_write, coerce: ->(value) { !!value }
      versioned_attribute :depth_test, coerce: ->(value) { !!value }
      versioned_attribute :blend, validate: ->(value) { value.is_a?(Hash) || BLENDS.include?(value.to_sym) }
      versioned_attribute :alpha_mode, coerce: :to_sym.to_proc,
                                          validate: ->(value) { ALPHA_MODES.include?(value) }
      versioned_attribute :alpha_cutoff, coerce: ->(value) { Float(value) },
                                           validate: ->(value) { value.between?(0.0, 1.0) }

      def transparent?
        transparent || opacity < 1.0 || alpha_mode == :blend
      end
    end
  end
end
