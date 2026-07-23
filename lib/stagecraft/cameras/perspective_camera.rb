# frozen_string_literal: true

module Stagecraft
  module Cameras
    class Perspective < Camera
      attr_reader :fov, :aspect, :near, :far

      def initialize(fov: 50.0, aspect: 1.0, near: 0.1, far: 2_000.0, **)
        super(**)
        @projection_revision = 0
        @cached_projection_revision = -1
        self.fov = fov
        self.aspect = aspect
        self.near = near
        self.far = far
      end

      def fov=(value)
        assign_projection_value(:@fov, Float(value)) { |number| number.positive? && number < 180.0 }
      end

      def aspect=(value)
        assign_projection_value(:@aspect, Float(value), &:positive?)
      end

      def near=(value)
        assign_projection_value(:@near, Float(value), &:positive?)
        validate_planes! if defined?(@far)
      end

      def far=(value)
        assign_projection_value(:@far, Float(value), &:positive?)
        validate_planes! if defined?(@near)
      end

      def projection_matrix
        return @projection_matrix if @cached_projection_revision == @projection_revision

        radians = fov * Math::PI / 180.0
        f = 1.0 / Math.tan(radians / 2.0)
        @projection_matrix = Larb::Mat4.new([
          f / aspect, 0.0, 0.0, 0.0,
          0.0, f, 0.0, 0.0,
          0.0, 0.0, far / (near - far), -1.0,
          0.0, 0.0, (near * far) / (near - far), 0.0
        ])
        @cached_projection_revision = @projection_revision
        @projection_matrix
      end

      private

      def assign_projection_value(variable, value)
        raise ArgumentError, "invalid projection value #{value}" unless yield(value)
        return value if instance_variable_defined?(variable) && instance_variable_get(variable) == value

        instance_variable_set(variable, value)
        @projection_revision += 1
        value
      end

      def validate_planes!
        raise ArgumentError, "far must be greater than near" unless far > near
      end
    end

    PerspectiveCamera = Perspective
  end
end
