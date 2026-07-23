# frozen_string_literal: true

module Stagecraft
  module Lights
    class Light < Node
      attr_reader :color, :intensity

      def initialize(color: Color.new(1.0), intensity: 1.0, **)
        super(**)
        self.color = color
        self.intensity = intensity
      end

      def color=(value)
        @color = Color.coerce(value)
      end

      def intensity=(value)
        number = Float(value)
        raise ArgumentError, "light intensity must be non-negative" if number.negative?

        @intensity = number
      end

      def direction
        rotation.to_larb * Larb::Vec3.forward
      end
    end
  end
end
