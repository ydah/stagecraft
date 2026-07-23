# frozen_string_literal: true

module Stagecraft
  module Cameras
    class Orthographic < Camera
      PROPERTIES = %i[left right top bottom near far].freeze

      attr_reader(*PROPERTIES)

      def initialize(left: -1.0, right: 1.0, top: 1.0, bottom: -1.0, near: 0.1, far: 2_000.0, **)
        super(**)
        @projection_revision = 0
        @cached_projection_revision = -1
        { left:, right:, top:, bottom:, near:, far: }.each do |name, value|
          public_send(:"#{name}=", value)
        end
        validate_extents!
      end

      PROPERTIES.each do |property|
        define_method(:"#{property}=") do |value|
          number = Float(value)
          variable = :"@#{property}"
          return number if instance_variable_defined?(variable) && instance_variable_get(variable) == number

          instance_variable_set(variable, number)
          @projection_revision += 1
          number
        end
      end

      def projection_matrix
        return @projection_matrix if @cached_projection_revision == @projection_revision

        validate_extents!
        width = right - left
        height = top - bottom
        depth = far - near
        @projection_matrix = Larb::Mat4.new([
          2.0 / width, 0.0, 0.0, 0.0,
          0.0, 2.0 / height, 0.0, 0.0,
          0.0, 0.0, -1.0 / depth, 0.0,
          -(right + left) / width, -(top + bottom) / height, -near / depth, 1.0
        ])
        @cached_projection_revision = @projection_revision
        @projection_matrix
      end

      private

      def validate_extents!
        raise ArgumentError, "left and right must differ" if left == right
        raise ArgumentError, "top and bottom must differ" if top == bottom
        raise ArgumentError, "far must be greater than near" unless far > near
      end
    end

    OrthographicCamera = Orthographic
  end
end
