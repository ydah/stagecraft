# frozen_string_literal: true

module Stagecraft
  module Materials
    class Unlit < Base
      def initialize(color: Color.new(1.0), map: nil, uv_transform: Larb::Mat3.new,
                     uv_set: 0, **)
        super(**)
        self.color = color
        self.map = map
        self.uv_transform = uv_transform
        self.uv_set = uv_set
      end

      versioned_attribute :color, coerce: Color.method(:coerce)
      versioned_attribute :map
      versioned_attribute :uv_transform, coerce: lambda { |value|
        value.is_a?(Larb::Mat3) ? value : Larb::Mat3.new(value.to_a)
      }
      versioned_attribute :uv_set, coerce: ->(value) { Integer(value) },
                                   validate: ->(value) { value.between?(0, 1) }
    end

    UnlitMaterial = Unlit
  end
end
