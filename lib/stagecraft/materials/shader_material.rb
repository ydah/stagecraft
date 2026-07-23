# frozen_string_literal: true

module Stagecraft
  module Materials
    class Shader < Base
      def initialize(wgsl:, uniforms: {}, **)
        super(**)
        self.wgsl = wgsl
        self.uniforms = uniforms
      end

      versioned_attribute :wgsl, coerce: lambda { |value|
        source = value.respond_to?(:to_wgsl) ? value.to_wgsl : value
        String(source).dup.freeze
      }
      versioned_attribute :uniforms, coerce: ->(value) { value.transform_keys(&:to_sym).freeze }
    end

    ShaderMaterial = Shader
  end
end
