# frozen_string_literal: true

module Stagecraft
  class App
    attr_reader :window, :renderer

    def initialize(title: "Stagecraft", width: 800, height: 600, msaa: 4,
                   window: :sdl3, renderer: nil, resizable: true)
      @window = build_window(window, title:, width:, height:, resizable:)
      @renderer = renderer || Renderer.new(window: @window, width:, height:, msaa:)
    rescue StandardError
      @window&.close
      raise
    end

    def aspect
      width, height = window.drawable_size
      height.zero? ? 1.0 : width.to_f / height
    end

    def run
      raise ArgumentError, "App#run requires a block" unless block_given?

      previous = monotonic_time
      loop do
        window.poll_events
        break if window.should_close?

        now = monotonic_time
        dt = (now - previous).clamp(0.0, 0.1)
        previous = now
        yield(dt)
        break if ENV["STAGECRAFT_SMOKE"] == "1"
      end
      self
    ensure
      begin
        renderer.dispose
      ensure
        window.close
      end
    end

    private

    def build_window(value, **options)
      return value unless value.is_a?(Symbol) || value.is_a?(String)

      case value.to_sym
      when :sdl3 then Window::Sdl3.new(**options)
      when :glfw then Window::Glfw.new(**options)
      else
        raise ArgumentError, "unknown window adapter #{value.inspect}"
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
