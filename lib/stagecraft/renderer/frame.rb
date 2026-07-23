# frozen_string_literal: true

module Stagecraft
  class Renderer
    class Frame
      attr_reader :texture, :width, :height

      def initialize(texture:, width:, height:, device:, queue:, readable:)
        @texture = texture
        @width = width
        @height = height
        @device = device
        @queue = queue
        @readable = readable
      end

      def read_pixels
        raise Error, "surface frames cannot be read after presentation; use Renderer.offscreen" unless @readable

        require "texel"
        bytes_per_row = align(width * 4, 256)
        padded = @queue.read_texture(
          source: { texture: },
          data_layout: { bytes_per_row:, rows_per_image: height },
          size: { width:, height:, depth_or_array_layers: 1 },
          device: @device
        )
        pixels = if bytes_per_row == width * 4
                   padded
                 else
                   height.times.map { |row| padded.byteslice(row * bytes_per_row, width * 4) }.join
                 end
        Texel::Image.new(
          width:, height:, channels: 4, dtype: :u8, color_space: :srgb, data: pixels
        )
      end

      private

      def align(value, alignment)
        ((value + alignment - 1) / alignment) * alignment
      end
    end
  end
end
