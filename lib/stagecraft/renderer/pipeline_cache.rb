# frozen_string_literal: true

module Stagecraft
  class Renderer
    class PipelineCache
      Key = Data.define(
        :material_class, :feature_bits, :vertex_layout_id, :blend_state, :depth_state,
        :cull_mode, :sample_count, :color_format, :shadow_pass
      )

      attr_reader :limit

      def initialize(limit: 256, on_change: nil)
        @limit = Integer(limit)
        raise ArgumentError, "pipeline cache limit must be positive" unless @limit.positive?

        @entries = {}
        @on_change = on_change
      end

      def fetch(key)
        if @entries.key?(key)
          value = @entries.delete(key)
          @entries[key] = value
          return value
        end

        value = yield
        @entries[key] = value
        @on_change&.call(1)
        evict! while @entries.length > limit
        value
      end

      def size
        @entries.size
      end

      def clear
        @entries.each_value { |value| release(value) }
        @on_change&.call(-@entries.length)
        @entries.clear
        self
      end

      private

      def evict!
        _key, value = @entries.shift
        release(value)
        @on_change&.call(-1)
      end

      def release(value)
        value.release if value.respond_to?(:release)
      end
    end
  end
end
