# frozen_string_literal: true

module Stagecraft
  module Materials
    class PBR < Base
      TEXTURE_ATTRIBUTES = %i[
        base_color_map metallic_roughness_map normal_map occlusion_map emissive_map
      ].freeze
      TRANSFORM_ATTRIBUTES = %i[
        base_color_uv_transform metallic_roughness_uv_transform normal_uv_transform
        occlusion_uv_transform emissive_uv_transform
      ].freeze

      def initialize(base_color: Color.new(1.0), base_color_map: nil, metallic: 1.0,
                     roughness: 1.0, metallic_roughness_map: nil, normal_map: nil,
                     normal_scale: 1.0, occlusion_map: nil, occlusion_strength: 1.0,
                     emissive: Color.new(0.0), emissive_map: nil, emissive_strength: 1.0,
                     base_color_uv_transform: Larb::Mat3.new,
                     metallic_roughness_uv_transform: Larb::Mat3.new,
                     normal_uv_transform: Larb::Mat3.new,
                     occlusion_uv_transform: Larb::Mat3.new,
                     emissive_uv_transform: Larb::Mat3.new, **)
        super(**)
        self.base_color = base_color
        self.base_color_map = base_color_map
        self.metallic = metallic
        self.roughness = roughness
        self.metallic_roughness_map = metallic_roughness_map
        self.normal_map = normal_map
        self.normal_scale = normal_scale
        self.occlusion_map = occlusion_map
        self.occlusion_strength = occlusion_strength
        self.emissive = emissive
        self.emissive_map = emissive_map
        self.emissive_strength = emissive_strength
        TRANSFORM_ATTRIBUTES.each do |name|
          self.public_send(:"#{name}=", binding.local_variable_get(name))
        end
      end

      versioned_attribute :base_color, coerce: Color.method(:coerce)
      versioned_attribute :metallic, coerce: ->(value) { Float(value) },
                                     validate: ->(value) { value.between?(0.0, 1.0) }
      versioned_attribute :roughness, coerce: ->(value) { Float(value) },
                                      validate: ->(value) { value.between?(0.0, 1.0) }
      versioned_attribute :normal_scale, coerce: ->(value) { Float(value) }
      versioned_attribute :occlusion_strength, coerce: ->(value) { Float(value) },
                                               validate: ->(value) { value.between?(0.0, 1.0) }
      versioned_attribute :emissive, coerce: Color.method(:coerce)
      versioned_attribute :emissive_strength, coerce: ->(value) { Float(value) },
                                              validate: ->(value) { value >= 0.0 }
      TEXTURE_ATTRIBUTES.each { |name| versioned_attribute(name) }
      TRANSFORM_ATTRIBUTES.each do |name|
        versioned_attribute name, coerce: lambda { |value|
          value.is_a?(Larb::Mat3) ? value : Larb::Mat3.new(value.to_a)
        }
      end
    end

    PBRMaterial = PBR
  end
end
