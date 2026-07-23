# frozen_string_literal: true

module Stagecraft
  module Animation
    class Action
      LOOPS = %i[repeat once ping_pong].freeze

      attr_reader :clip, :time, :loop
      attr_accessor :weight, :time_scale, :enabled, :clamp_when_finished

      def initialize(clip, loop: :repeat, fade_in: 0.0)
        @clip = clip
        @loop = loop.to_sym
        raise ArgumentError, "invalid animation loop #{loop.inspect}" unless LOOPS.include?(@loop)

        @time = 0.0
        @weight = fade_in.to_f.positive? ? 0.0 : 1.0
        @fade_duration = [Float(fade_in), 0.0].max
        @fade_elapsed = 0.0
        @time_scale = 1.0
        @enabled = true
        @clamp_when_finished = true
        @direction = 1.0
      end

      def advance(dt)
        return time unless enabled

        update_fade(dt)
        duration = clip.duration
        return @time = 0.0 if duration.zero?

        @time += Float(dt) * time_scale * @direction
        apply_loop(duration)
        time
      end

      def stop
        @enabled = false
        self
      end

      private

      def update_fade(dt)
        return unless @fade_duration.positive? && weight < 1.0

        @fade_elapsed += dt
        @weight = [@fade_elapsed / @fade_duration, 1.0].min
      end

      def apply_loop(duration)
        case loop
        when :repeat
          @time %= duration
        when :ping_pong
          if @time > duration
            @time = duration - (@time - duration)
            @direction = -1.0
          elsif @time.negative?
            @time = -@time
            @direction = 1.0
          end
        when :once
          return unless @time > duration || @time.negative?

          @time = @time.clamp(0.0, duration)
          @enabled = false unless clamp_when_finished
        end
      end
    end
  end
end
