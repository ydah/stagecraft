# frozen_string_literal: true

module Stagecraft
  module Materials
    class Unlit < Base
      def initialize(color: Color.new(1.0), map: nil, uv_transform: Larb::Mat3.new, **)
        super(**)
        self.color = color
        self.map = map
        self.uv_transform = uv_transform
      end

      versioned_attribute :color, coerce: Color.method(:coerce)
      versioned_attribute :map
      versioned_attribute :uv_transform, coerce: lambda { |value|
        value.is_a?(Larb::Mat3) ? value : Larb::Mat3.new(value.to_a)
      }
    end

    UnlitMaterial = Unlit
  end
end
