# frozen_string_literal: true

module Stagecraft
  module Window
    class Glfw < Adapter
      attr_reader :native

      def initialize(title:, width:, height:, resizable: true, surface_factory: nil)
        super()
        require "glfw"
        ::GLFW.init
        @native = ::GLFW::Window.new(
          width, height, title,
          client_api: ::GLFW::GLFW_NO_API,
          resizable:
        )
        @surface_factory = surface_factory
        attach_callbacks
      end

      def create_surface(instance)
        return @surface_factory.call(instance, native) if @surface_factory

        raise Error, <<~MESSAGE.strip
          glfw-ruby does not expose a portable WebGPU surface handle; pass surface_factory:
          or use window: :sdl3, whose native surface bridge is built into wgpu
        MESSAGE
      end

      def poll_events
        ::GLFW.poll_events
        []
      end

      def should_close?
        native.should_close?
      end

      def drawable_size
        native.framebuffer_size
      end

      def close
        native.destroy
        ::GLFW.terminate
      end

      private

      def attach_callbacks
        native.on_mouse_button do |_window, button, action, _mods|
          x, y = native.cursor_pos
          emit(:pointer_button, button, action == :press, x, y)
        end
        native.on_cursor_pos do |_window, x, y|
          previous = @cursor_position || [x, y]
          @cursor_position = [x, y]
          emit(:pointer_move, x, y, x - previous[0], y - previous[1])
        end
        native.on_scroll { |_window, x, y| emit(:scroll, x, y) }
        native.on_resize { |_window, width, height| emit(:resize, width, height) }
      end
    end

    GLFW = Glfw
  end
end
