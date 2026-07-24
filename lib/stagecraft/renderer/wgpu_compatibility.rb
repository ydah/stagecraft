# frozen_string_literal: true

module Stagecraft
  class Renderer
    module WGPUCompatibility
      module_function

      def install!
        return unless defined?(::WGPU::Native::TextureViewDescriptor)

        native = ::WGPU::Native
        descriptor = native::TextureViewDescriptor
        return if descriptor.members.include?(:usage)

        native.send(:remove_const, :TextureViewDescriptor)
        native.const_set(:TextureViewDescriptor, texture_view_descriptor_class(native))
      end

      def texture_view_descriptor_class(native)
        Class.new(FFI::Struct) do
          layout :next_in_chain, :pointer,
                 :label, native::StringView,
                 :format, native::TextureFormat,
                 :dimension, native::TextureViewDimension,
                 :base_mip_level, :uint32,
                 :mip_level_count, :uint32,
                 :base_array_layer, :uint32,
                 :array_layer_count, :uint32,
                 :aspect, native::TextureAspect,
                 :usage, :uint64

          def initialize(*arguments)
            super
            self[:usage] = 0
          end
        end
      end
      private_class_method :texture_view_descriptor_class
    end
  end
end
