# frozen_string_literal: true

module Stagecraft
  module Lights
    class Point < Light
      attr_reader :range

      def initialize(range: Float::INFINITY, **)
        super(**)
        self.range = range
      end

      def range=(value)
        number = Float(value)
        raise ArgumentError, "light range must be positive" unless number.positive?

        @range = number
      end
    end

    PointLight = Point
  end
end
