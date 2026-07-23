# frozen_string_literal: true

module Stagecraft
  module Lights
    class Spot < Point
      attr_reader :inner_angle, :outer_angle

      def initialize(inner_angle: 0.0, outer_angle: Math::PI / 4.0, **)
        super(**)
        @inner_angle = Float(inner_angle)
        @outer_angle = Float(outer_angle)
        validate_angles!
      end

      def inner_angle=(value)
        @inner_angle = Float(value)
        validate_angles! if defined?(@outer_angle)
      end

      def outer_angle=(value)
        @outer_angle = Float(value)
        validate_angles! if defined?(@inner_angle)
      end

      private

      def validate_angles!
        valid = inner_angle >= 0.0 && outer_angle > 0.0 &&
                inner_angle <= outer_angle && outer_angle <= (Math::PI / 2.0)
        raise ArgumentError, "spot angles must satisfy 0 <= inner <= outer <= pi/2" unless valid
      end
    end

    SpotLight = Spot
  end
end
