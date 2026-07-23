# frozen_string_literal: true

module Stagecraft
  class Renderer
    class Stats
      COUNTERS = %i[draw_calls triangles buffers textures pipelines visible_objects culled_objects].freeze

      attr_reader(*COUNTERS)

      def initialize
        COUNTERS.each { |counter| instance_variable_set(:"@#{counter}", 0) }
      end

      def reset_frame!
        @draw_calls = 0
        @triangles = 0
        @visible_objects = 0
        @culled_objects = 0
        self
      end

      def increment(counter, amount = 1)
        raise ArgumentError, "unknown stats counter #{counter.inspect}" unless COUNTERS.include?(counter)

        instance_variable_set(:"@#{counter}", public_send(counter) + amount)
      end

      def decrement(counter, amount = 1)
        increment(counter, -amount)
      end

      def to_h
        COUNTERS.to_h { |counter| [counter, public_send(counter)] }
      end

      def to_s
        to_h.map { |name, value| "#{name}=#{value}" }.join(" ")
      end
    end
  end
end
