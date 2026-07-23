# frozen_string_literal: true

module Stagecraft
  module Loaders
    class GLTF
      Result = Data.define(:scene, :scenes, :animations, :cameras)

      ATTRIBUTE_NAMES = {
        POSITION: :position,
        NORMAL: :normal,
        TEXCOORD_0: :uv,
        TEXCOORD_1: :uv1,
        TANGENT: :tangent,
        COLOR_0: :color,
        JOINTS_0: :joints,
        WEIGHTS_0: :weights
      }.freeze
      TOPOLOGIES = {
        points: :point_list,
        lines: :line_list,
        line_strip: :line_strip,
        triangles: :triangle_list,
        triangle_strip: :triangle_strip
      }.freeze

      def self.load(source)
        require "rgltf"
        require "texel"

        document = source.is_a?(Rgltf::Document) ? source : Rgltf.load(source)
        new(document).convert
      end

      def initialize(document)
        @document = document
        @textures = {}
        @materials = {}
      end

      def convert
        source_scenes = @document.scenes
        converted = source_scenes.map { |scene| convert_scene(scene) }
        default_index = @document.default_scene && source_scenes.index(@document.default_scene)
        default_index ||= 0
        default_scene = converted[default_index] || convert_scene(nil)
        mapping = @scene_mappings.fetch(default_scene.object_id)
        Result.new(
          scene: default_scene,
          scenes: converted.empty? ? [default_scene] : converted,
          animations: convert_animations(mapping),
          cameras: converted_cameras(mapping)
        )
      end

      private

      def convert_scene(source_scene)
        @scene_mappings ||= {}
        mapping = {}
        stage_scene = Scene.new(name: source_scene&.name)
        @document.nodes.each { |node| build_node(node, mapping) }
        roots = source_scene ? source_scene.nodes : inferred_roots
        roots.each { |root| stage_scene.add(mapping.fetch(root)) }
        @document.nodes.each { |node| decorate_node(node, mapping) }
        @scene_mappings[stage_scene.object_id] = mapping
        stage_scene
      end

      def inferred_roots
        children = @document.nodes.flat_map(&:children)
        @document.nodes.reject { |node| children.include?(node) }
      end

      def build_node(source, mapping)
        return mapping[source] if mapping.key?(source)

        node = transform_node(source)
        mapping[source] = node
        source.children.each { |child| node.add(build_node(child, mapping)) }
        node
      end

      def transform_node(source)
        return trs_node(source) if source.trs?

        matrix = Larb::Mat4.new(source.matrix)
        position = matrix.extract_translation
        rotation = matrix.extract_rotation
        scale = matrix.extract_scale
        recomposed = Larb::Mat4.translation(*position.to_a) *
                     rotation.to_mat4 *
                     Larb::Mat4.scaling(*scale.to_a)
        return MatrixNode.new(matrix, name: source.name) unless matrix.near?(recomposed)

        Node.new(name: source.name).tap do |node|
          node.position.set(position)
          node.rotation.set(rotation)
          node.scale.set(scale)
        end
      rescue StandardError
        MatrixNode.new(matrix, name: source.name)
      end

      def trs_node(source)
        Node.new(name: source.name).tap do |node|
          node.position.set(source.translation)
          node.rotation.set(source.rotation)
          node.scale.set(source.scale)
        end
      end

      def decorate_node(source, mapping)
        target = mapping.fetch(source)
        source.mesh&.primitives&.each_with_index do |primitive, index|
          target.add(convert_primitive(source, primitive, index, mapping))
        end
        target.add(convert_camera(source.camera)) if source.camera
        light = source.extension("KHR_lights_punctual")
        target.add(convert_light(light.light)) if light
      end

      def convert_primitive(source_node, primitive, index, mapping)
        geometry = convert_geometry(primitive)
        material = convert_material(primitive.material)
        name = source_node.mesh.name
        name = "#{source_node.name || name || "mesh"} primitive #{index}" if source_node.mesh.primitives.length > 1
        Mesh.new(geometry, material, name:).tap do |mesh|
          weights = source_node.weights || source_node.mesh.weights
          mesh.morph_weights = weights.dup if weights
          mesh.skin = convert_skin(source_node.skin, mapping) if source_node.skin
        end
      end

      def convert_geometry(primitive)
        topology = TOPOLOGIES.fetch(primitive.mode, :triangle_list)
        geometry = Geometry.new(topology:)
        primitive.attributes.each do |semantic, accessor|
          name = ATTRIBUTE_NAMES[semantic]
          next unless name

          data, format = attribute_payload(semantic, accessor)
          raise Error, "glTF attribute #{semantic} has no WebGPU vertex format" unless format

          geometry.set_attribute(name, data:, format:, count: accessor.count)
        end
        raise Error, "glTF primitive has no POSITION attribute" unless geometry.attribute(:position)
        if %i[line_loop triangle_fan].include?(primitive.mode)
          geometry.topology = primitive.mode == :line_loop ? :line_list : :triangle_list
          geometry.set_index(data: expanded_indices(primitive), format: :uint32)
        elsif primitive.indices
          data, format = index_data(primitive.indices)
          geometry.set_index(data:, format:)
        end
        geometry
      end

      def attribute_payload(semantic, accessor)
        return expanded_color(accessor) if semantic == :COLOR_0 &&
                                           accessor.type == "VEC3" &&
                                           accessor.vertex_format.nil?

        [accessor.packed, accessor.vertex_format]
      end

      def expanded_color(accessor)
        case accessor.component_type
        when :u8
          values = accessor.packed.unpack("C*").each_slice(3).flat_map { |color| [*color, 255] }
          [values.pack("C*"), :unorm8x4]
        when :u16
          values = accessor.packed.unpack("S<*").each_slice(3).flat_map { |color| [*color, 65_535] }
          [values.pack("S<*"), :unorm16x4]
        else
          [accessor.packed, accessor.vertex_format]
        end
      end

      def expanded_indices(primitive)
        values = if primitive.indices
                   primitive.indices.to_a.map { |value| value.is_a?(Array) ? value.first : value }
                 else
                   (0...primitive.attributes.fetch(:POSITION).count).to_a
                 end
        expanded = if primitive.mode == :line_loop
                     return "".b if values.empty?

                     values.each_with_index.flat_map { |value, index| [value, values[(index + 1) % values.length]] }
                   else
                     (1...(values.length - 1)).flat_map { |index| [values.first, values[index], values[index + 1]] }
                   end
        expanded.pack("L<*")
      end

      def index_data(accessor)
        case accessor.component_type
        when :u8 then [accessor.packed_as_u32, :uint32]
        when :u16 then [accessor.packed, :uint16]
        when :u32 then [accessor.packed, :uint32]
        else raise Error, "unsupported glTF index component #{accessor.component_type}"
        end
      end

      def convert_material(source)
        return Materials::PBR.new unless source

        @materials[source] ||= begin
          pbr = source.pbr
          common = {
            side: source.double_sided ? :double : :front,
            alpha_mode: source.alpha_mode,
            alpha_cutoff: source.alpha_cutoff,
            transparent: source.alpha_mode == :blend
          }
          if source.unlit?
            Materials::Unlit.new(
              **common,
              color: pbr.base_color_factor,
              map: texture_from_info(pbr.base_color_texture, :srgb),
              uv_transform: uv_transform(pbr.base_color_texture)
            )
          else
            Materials::PBR.new(
              **common,
              base_color: pbr.base_color_factor,
              base_color_map: texture_from_info(pbr.base_color_texture, :srgb),
              base_color_uv_transform: uv_transform(pbr.base_color_texture),
              metallic: pbr.metallic_factor,
              roughness: pbr.roughness_factor,
              metallic_roughness_map: texture_from_info(pbr.metallic_roughness_texture, :linear),
              metallic_roughness_uv_transform: uv_transform(pbr.metallic_roughness_texture),
              normal_map: texture_from_info(source.normal_texture, :linear),
              normal_scale: source.normal_texture&.scale || 1.0,
              normal_uv_transform: uv_transform(source.normal_texture),
              occlusion_map: texture_from_info(source.occlusion_texture, :linear),
              occlusion_strength: source.occlusion_texture&.strength || 1.0,
              occlusion_uv_transform: uv_transform(source.occlusion_texture),
              emissive: source.emissive_factor,
              emissive_map: texture_from_info(source.emissive_texture, :srgb),
              emissive_strength: source.extension("KHR_materials_emissive_strength")&.emissive_strength || 1.0,
              emissive_uv_transform: uv_transform(source.emissive_texture)
            )
          end
        end
      end

      def texture_from_info(info, color_space)
        return unless info

        source = info.texture
        @textures[[source, color_space]] ||= begin
          raise Error, "glTF texture has no image source" unless source.source

          image = Texel.load(source.source.bytes, channels: 4, color_space:)
          Textures::Texture.new(image, sampler: convert_sampler(source.sampler), color_space:)
        end
      end

      def convert_sampler(source)
        return Textures::SamplerState.new unless source

        min_filter, mipmap_filter = split_min_filter(source.min_filter)
        Textures::SamplerState.new(
          wrap_u: source.wrap_s,
          wrap_v: source.wrap_t,
          mag_filter: source.mag_filter || :linear,
          min_filter:,
          mipmap_filter:
        )
      end

      def split_min_filter(filter)
        {
          nil => %i[linear linear],
          nearest: %i[nearest nearest],
          linear: %i[linear linear],
          nearest_mipmap_nearest: %i[nearest nearest],
          linear_mipmap_nearest: %i[linear nearest],
          nearest_mipmap_linear: %i[nearest linear],
          linear_mipmap_linear: %i[linear linear]
        }.fetch(filter)
      end

      def uv_transform(info)
        matrix = info&.transform&.uv_matrix
        matrix ? Larb::Mat3.new(matrix) : Larb::Mat3.new
      end

      def convert_skin(source, mapping)
        matrices = if source.inverse_bind_matrices
                     source.inverse_bind_matrices.to_a.map { |values| Larb::Mat4.new(values) }
                   end
        Skin.new(
          joints: source.joints.map { |joint| mapping.fetch(joint) },
          inverse_bind_matrices: matrices,
          skeleton: source.skeleton && mapping.fetch(source.skeleton)
        )
      end

      def convert_camera(source)
        camera = case source.type
                 when :perspective
                   value = source.perspective
                   Cameras::Perspective.new(
                     fov: value.yfov * 180.0 / Math::PI,
                     aspect: value.aspect_ratio || 1.0,
                     near: value.znear,
                     far: value.zfar || 1.0e9
                   )
                 when :orthographic
                   value = source.orthographic
                   Cameras::Orthographic.new(
                     left: -value.xmag,
                     right: value.xmag,
                     top: value.ymag,
                     bottom: -value.ymag,
                     near: value.znear,
                     far: value.zfar
                   )
                 end
        camera.name = source.name
        camera
      end

      def convert_light(source)
        options = { name: source.name, color: [*source.color, 1.0], intensity: source.intensity }
        case source.type
        when :directional then Lights::Directional.new(**options)
        when :point then Lights::Point.new(**options, range: source.range || Float::INFINITY)
        when :spot
          Lights::Spot.new(
            **options,
            range: source.range || Float::INFINITY,
            inner_angle: source.spot.inner_cone_angle,
            outer_angle: source.spot.outer_cone_angle
          )
        end
      end

      def convert_animations(mapping)
        @document.animations.map do |animation|
          tracks = animation.channels.filter_map do |channel|
            next unless channel.target_node

            sampler = channel.sampler
            Animation::Track.new(
              times: sampler.input.packed,
              values: sampler.output.packed,
              target: mapping.fetch(channel.target_node),
              target_path: channel.target_path,
              interpolation: sampler.interpolation,
              value_size: animation_value_size(channel)
            )
          end
          Animation::Clip.new(name: animation.name, tracks:)
        end
      end

      def animation_value_size(channel)
        return unless channel.target_path == :weights

        sampler = channel.sampler
        multiplier = sampler.interpolation == :cubicspline ? 3 : 1
        sampler.output.count / (sampler.input.count * multiplier)
      end

      def converted_cameras(mapping)
        @document.nodes.filter_map do |node|
          next unless node.camera

          mapping.fetch(node).children.find { |child| child.is_a?(Cameras::Camera) }
        end
      end
    end
  end
end
