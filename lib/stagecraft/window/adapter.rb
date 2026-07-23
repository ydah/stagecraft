# frozen_string_literal: true

module Stagecraft
  module Window
    class Adapter
      def initialize
        @callbacks = Hash.new { |hash, key| hash[key] = [] }
      end

      def on_pointer_button(&block)
        subscribe(:pointer_button, &block)
      end

      def on_pointer_move(&block)
        subscribe(:pointer_move, &block)
      end

      def on_scroll(&block)
        subscribe(:scroll, &block)
      end

      def on_resize(&block)
        subscribe(:resize, &block)
      end

      private

      def subscribe(event, &block)
        @callbacks[event] << block
        self
      end

      def emit(event, ...)
        @callbacks[event].each { |callback| callback.call(...) }
      end
    end
  end
end
