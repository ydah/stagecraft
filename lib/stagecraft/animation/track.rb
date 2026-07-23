# frozen_string_literal: true

module Stagecraft
  module Animation
    class Track
      PATH_COMPONENTS = { translation: 3, rotation: 4, scale: 3 }.freeze
      INTERPOLATIONS = %i[linear step cubicspline].freeze

      attr_reader :times, :values, :target, :target_path, :interpolation, :value_size

      def initialize(times:, values:, target:, target_path:, interpolation: :linear, value_size: nil)
        @times = unpack(times)
        @values = unpack(values)
        @target = target
        @target_path = target_path.to_sym
        @interpolation = interpolation.to_sym
        raise ArgumentError, "unsupported interpolation #{interpolation.inspect}" unless INTERPOLATIONS.include?(@interpolation)
        raise ArgumentError, "animation times cannot be empty" if @times.empty?
        raise ArgumentError, "animation times must be sorted" unless @times.each_cons(2).all? { |left, right| left <= right }

        @value_size = value_size || infer_value_size
        expected = @times.length * @value_size * (cubicspline? ? 3 : 1)
        raise ArgumentError, "animation value count #{values_count} does not match expected #{expected}" unless values_count == expected
      end

      def duration
        times.last
      end

      def sample(time, out = nil)
        value = sample_value(Float(time))
        assign(out, value) if out
        value
      end

      private

      def unpack(value)
        value.is_a?(String) ? value.unpack("e*") : value.to_a.map(&:to_f)
      end

      def infer_value_size
        PATH_COMPONENTS[target_path] || begin
          divisor = times.length * (cubicspline? ? 3 : 1)
          values.length / divisor
        end
      end

      def values_count
        values.length
      end

      def cubicspline?
        interpolation == :cubicspline
      end

      def sample_value(time)
        return key_value(0) if time <= times.first
        return key_value(times.length - 1) if time >= times.last

        upper = times.bsearch_index { |key_time| key_time > time }
        lower = upper - 1
        duration = times[upper] - times[lower]
        amount = duration.zero? ? 0.0 : (time - times[lower]) / duration
        case interpolation
        when :step then key_value(lower)
        when :cubicspline then cubic_value(lower, upper, amount, duration)
        else linear_value(lower, upper, amount)
        end
      end

      def key_value(index)
        value_index = cubicspline? ? ((index * 3) + 1) : index
        slice(value_index)
      end

      def linear_value(lower, upper, amount)
        first = key_value(lower)
        second = key_value(upper)
        return quaternion(first).slerp(quaternion(second), amount).to_a if target_path == :rotation

        first.zip(second).map { |left, right| left + ((right - left) * amount) }
      end

      def cubic_value(lower, upper, amount, duration)
        p0 = slice((lower * 3) + 1)
        m0 = slice((lower * 3) + 2)
        p1 = slice((upper * 3) + 1)
        m1 = slice(upper * 3)
        t2 = amount * amount
        t3 = t2 * amount
        h00 = (2 * t3) - (3 * t2) + 1
        h10 = t3 - (2 * t2) + amount
        h01 = (-2 * t3) + (3 * t2)
        h11 = t3 - t2
        result = value_size.times.map do |index|
          (h00 * p0[index]) + (h10 * duration * m0[index]) +
            (h01 * p1[index]) + (h11 * duration * m1[index])
        end
        target_path == :rotation ? quaternion(result).normalize.to_a : result
      end

      def slice(index)
        values.slice(index * value_size, value_size)
      end

      def quaternion(value)
        Larb::Quat.new(*value)
      end

      def assign(out, value)
        if out.respond_to?(:set)
          out.set(*value)
        elsif out.respond_to?(:replace)
          out.replace(value)
        else
          raise ArgumentError, "animation output must support #set or #replace"
        end
      end
    end
  end
end
