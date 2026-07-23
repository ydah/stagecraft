# frozen_string_literal: true

require "set"

module Stagecraft
  class Renderer
    module Features
      ORDER = %i[
        HAS_UV HAS_NORMAL HAS_TANGENT HAS_VERTEX_COLOR HAS_BASECOLOR_MAP HAS_MR_MAP
        HAS_NORMAL_MAP HAS_OCCLUSION_MAP HAS_EMISSIVE_MAP SKINNED ALPHA_MASK DOUBLE_SIDED
      ].freeze
      ATTRIBUTE_FEATURES = {
        uv: :HAS_UV,
        normal: :HAS_NORMAL,
        tangent: :HAS_TANGENT,
        color: :HAS_VERTEX_COLOR
      }.freeze

      module_function

      def for(mesh)
        values = Set.new
        ATTRIBUTE_FEATURES.each { |attribute, feature| values << feature if mesh.geometry.attribute(attribute) }
        material_features(mesh.material, values)
        values << :SKINNED if mesh.skin
        values.freeze
      end

      def bits(features)
        ORDER.each_with_index.sum { |feature, index| features.include?(feature) ? (1 << index) : 0 }
      end

      def vertex_layout_id(geometry)
        geometry.attributes.sort_by(&:first).map { |name, attribute| [name, attribute.format] }.hash
      end

      def material_features(material, values)
        return unless material.is_a?(Materials::PBR)

        values << :HAS_BASECOLOR_MAP if material.base_color_map
        values << :HAS_MR_MAP if material.metallic_roughness_map
        values << :HAS_NORMAL_MAP if material.normal_map
        values << :HAS_OCCLUSION_MAP if material.occlusion_map
        values << :HAS_EMISSIVE_MAP if material.emissive_map
        values << :ALPHA_MASK if material.alpha_mode == :mask
        values << :DOUBLE_SIDED if material.side == :double
      end
      private_class_method :material_features
    end
  end
end
