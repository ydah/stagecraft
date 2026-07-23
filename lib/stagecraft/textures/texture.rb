# frozen_string_literal: true

module Stagecraft
  module Textures
    class Texture
      attr_reader :image, :sampler, :color_space, :version

      def initialize(image = nil, sampler: SamplerState.new, color_space: nil)
        @version = 0
        @disposed = false
        @dispose_callbacks = []
        self.image = image
        self.sampler = sampler
        self.color_space = color_space
      end

      def self.load(source, **options)
        require "texel"
        color_space = options.delete(:color_space)
        channels = options.delete(:channels)
        image = Texel.load(source, channels:, color_space:)
        new(image, color_space:, **options)
      end

      def image=(value)
        assign(:@image, value)
      end

      def sampler=(value)
        raise ArgumentError, "expected a SamplerState" unless value.is_a?(SamplerState)

        assign(:@sampler, value)
      end

      def color_space=(value)
        assign(:@color_space, value&.to_sym)
      end

      def on_dispose(&block)
        @dispose_callbacks << block
        self
      end

      def dispose
        return self if @disposed

        @disposed = true
        @version += 1
        @dispose_callbacks.each { |callback| callback.call(self) }
        @dispose_callbacks.clear
        self
      end

      def disposed?
        @disposed
      end

      private

      def assign(variable, value)
        return value if instance_variable_defined?(variable) && instance_variable_get(variable) == value

        instance_variable_set(variable, value)
        @version += 1
        value
      end
    end
  end

  Texture = Textures::Texture
end
