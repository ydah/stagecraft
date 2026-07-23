# frozen_string_literal: true

module Stagecraft
  module Window
    class Sdl3 < Adapter
      attr_reader :native

      def initialize(title:, width:, height:, resizable: true)
        super()
        require "wgpu"
        require "wgpu/window"
        @native = WGPU::Window::SDLWindow.new(title:, width:, height:, resizable:)
        @close_requested = false
      end

      def create_surface(instance)
        native.create_surface(instance)
      end

      def poll_events
        events = native.poll_events
        events.each { |event| dispatch(event) }
        events
      end

      def should_close?
        @close_requested
      end

      def drawable_size
        native.drawable_size
      end

      def close
        native.close
      end

      private

      def dispatch(event)
        @close_requested = true if event.quit? ||
                                   (event.respond_to?(:close_requested?) && event.close_requested?)
        if event.mouse_button_down? || event.mouse_button_up?
          emit(:pointer_button, event.button, event.mouse_button_down?, event.x, event.y)
        elsif event.mouse_motion?
          emit(:pointer_move, event.x, event.y, event.xrel, event.yrel)
        elsif event.is_a?(::SDL3::MouseWheelEvent)
          emit(:scroll, event.x, event.y)
        elsif event.respond_to?(:resized?) && event.resized?
          emit(:resize, event.data1, event.data2)
        end
      end
    end

    SDL3 = Sdl3
  end
end
