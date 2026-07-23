# frozen_string_literal: true

module Stagecraft
  module Bounding
    class Box3
      attr_reader :min, :max

      def initialize(min = nil, max = nil)
        @min = min || Larb::Vec3.new(Float::INFINITY, Float::INFINITY, Float::INFINITY)
        @max = max || Larb::Vec3.new(-Float::INFINITY, -Float::INFINITY, -Float::INFINITY)
      end

      def expand_by_point(point)
        @min = min.min(point)
        @max = max.max(point)
        self
      end

      def empty?
        min.x > max.x || min.y > max.y || min.z > max.z
      end

      def center
        return Larb::Vec3.new if empty?

        (min + max) * 0.5
      end

      def size
        empty? ? Larb::Vec3.new : max - min
      end

      def intersects_ray?(origin, inverse_direction)
        tmin = -Float::INFINITY
        tmax = Float::INFINITY
        3.times do |axis|
          first = (min[axis] - origin[axis]) * inverse_direction[axis]
          second = (max[axis] - origin[axis]) * inverse_direction[axis]
          first, second = second, first if first > second
          tmin = [tmin, first].max
          tmax = [tmax, second].min
          return false if tmax < [tmin, 0.0].max
        end
        true
      end
    end

    class Sphere
      attr_reader :center, :radius

      def initialize(center = Larb::Vec3.new, radius = 0.0)
        @center = center
        @radius = radius.to_f
      end

      def transform(matrix)
        elements = matrix.to_a
        scale = [
          Math.sqrt(elements[0]**2 + elements[1]**2 + elements[2]**2),
          Math.sqrt(elements[4]**2 + elements[5]**2 + elements[6]**2),
          Math.sqrt(elements[8]**2 + elements[9]**2 + elements[10]**2)
        ].max
        transformed = matrix * center.to_vec4(1.0)
        self.class.new(transformed.xyz, radius * scale)
      end

      def intersects_ray?(origin, direction)
        offset = center - origin
        projected = offset.dot(direction)
        distance_squared = offset.length_squared - (projected * projected)
        return nil if distance_squared > radius * radius

        half_chord = Math.sqrt((radius * radius) - distance_squared)
        near = projected - half_chord
        far = projected + half_chord
        far.negative? ? nil : [near, 0.0].max
      end
    end

    class Plane
      attr_reader :normal, :constant

      def initialize(normal, constant)
        length = normal.length
        raise ArgumentError, "plane normal cannot be zero" if length.zero?

        @normal = normal / length
        @constant = constant.to_f / length
      end

      def distance_to_point(point)
        normal.dot(point) + constant
      end

      def intersects_sphere?(sphere)
        distance_to_point(sphere.center) >= -sphere.radius
      end
    end

    class Frustum
      attr_reader :planes

      def initialize(planes)
        raise ArgumentError, "frustum requires six planes" unless planes.length == 6

        @planes = planes.freeze
      end

      def self.from_matrix(matrix)
        m = matrix.to_a
        row = ->(index) { [m[index], m[index + 4], m[index + 8], m[index + 12]] }
        r0, r1, r2, r3 = 4.times.map { |index| row.call(index) }
        coefficients = [
          combine(r3, r0, 1), combine(r3, r0, -1),
          combine(r3, r1, 1), combine(r3, r1, -1),
          r2, combine(r3, r2, -1)
        ]
        new(coefficients.map { |a, b, c, d| Plane.new(Larb::Vec3.new(a, b, c), d) })
      end

      def intersects_sphere?(sphere)
        planes.all? { |plane| plane.intersects_sphere?(sphere) }
      end

      def self.combine(left, right, sign)
        4.times.map { |index| left[index] + (right[index] * sign) }
      end
      private_class_method :combine
    end
  end
end
