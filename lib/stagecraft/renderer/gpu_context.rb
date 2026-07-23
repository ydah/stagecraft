# frozen_string_literal: true

module Stagecraft
  class Renderer
    class GPUContext
      attr_reader :instance, :adapter, :device, :queue, :surface, :surface_format, :width, :height

      def initialize(window: nil, width:, height:, device: nil, queue: nil, surface: nil)
        @window = window
        @width = Integer(width)
        @height = Integer(height)
        @owns_device = device.nil?
        if device
          @device = device
          @queue = queue || device.queue
          @surface = surface
          @adapter = device.respond_to?(:adapter) ? device.adapter : nil
        else
          initialize_wgpu
        end
        @surface_format = choose_surface_format
        configure_surface if @surface
      end

      def resize(width, height)
        next_width = [Integer(width), 1].max
        next_height = [Integer(height), 1].max
        return false if next_width == @width && next_height == @height

        @width = next_width
        @height = next_height
        configure_surface if surface
        true
      end

      def current_target
        raise Error, "renderer has no surface" unless surface

        texture = surface.current_texture
        [texture, texture.create_view]
      end

      def present
        surface&.present
      end

      def dispose
        surface&.unconfigure
        surface&.release
        return unless @owns_device

        device.destroy if device.respond_to?(:destroy)
        device.release if device.respond_to?(:release)
        adapter.release if adapter&.respond_to?(:release)
        instance.release if instance&.respond_to?(:release)
      end

      private

      def initialize_wgpu
        require "wgpu"
        @instance = WGPU::Instance.new
        @surface = @window&.create_surface(instance)
        @adapter = instance.request_adapter(compatible_surface: surface)
        @device = adapter.request_device(label: "stagecraft device")
        @queue = device.queue
      end

      def choose_surface_format
        return :rgba8_unorm_srgb unless surface

        formats = surface.capabilities(adapter).fetch(:formats)
        formats.find { |format| format.to_s.end_with?("_srgb") } ||
          formats.find { |format| %i[bgra8_unorm rgba8_unorm].include?(format) } ||
          formats.first ||
          :bgra8_unorm
      end

      def configure_surface
        surface.configure(
          device:,
          format: surface_format,
          width:,
          height:,
          present_mode: :fifo
        )
      end
    end
  end
end
