# frozen_string_literal: true

module Stagecraft
  class Renderer
    class PipelineFactory
      MaterialBinding = Struct.new(:version, :texture_versions, :buffer, :bind_group, :signature)
      ATTRIBUTE_LOCATIONS = {
        position: 0, normal: 1, uv: 2, tangent: 3, color: 4, joints: 5, weights: 6,
        uv1: 7
      }.freeze
      FORMAT_SIZES = {
        float32: 4, float32x2: 8, float32x3: 12, float32x4: 16,
        sint8x2: 2, sint8x4: 4, snorm8x2: 2, snorm8x4: 4,
        sint16x2: 4, sint16x4: 8, snorm16x2: 4, snorm16x4: 8,
        uint16: 2, uint16x2: 4, uint16x4: 8,
        unorm16x2: 4, unorm16x4: 8,
        uint32: 4, uint32x2: 8, uint32x3: 12, uint32x4: 16,
        unorm8x2: 2, unorm8x4: 4, uint8x2: 2, uint8x4: 4
      }.freeze

      def initialize(device:, queue:, resources:, resource_cache:, stats:, sample_count:)
        @device = device
        @queue = queue
        @resources = resources
        @resource_cache = resource_cache
        @sample_count = sample_count
        @stats = stats
        @cache = PipelineCache.new(on_change: ->(amount) { stats.increment(:pipelines, amount) })
        @material_layouts = {}
        @material_bindings = {}
      end

      def pipeline_for(item, shadow: false)
        material = item.mesh.material
        layout_signature = material_layout_signature(material)
        key = PipelineCache::Key.new(
          material_class: [material.class, layout_signature],
          feature_bits: Features.bits(item.features),
          vertex_layout_id: Features.vertex_layout_id(item.mesh.geometry),
          blend_state: material.blend,
          depth_state: [material.depth_test, material.depth_write],
          cull_mode: material.side,
          sample_count: shadow ? 1 : @sample_count,
          color_format: shadow ? :depth32_float : :rgba16_float,
          shadow_pass: shadow
        )
        @cache.fetch(key) { build_pipeline(item, shadow:) }
      end

      def material_binding(material, features)
        signature = material_layout_signature(material)
        key = [material.object_id, signature]
        texture_versions = material_textures(material).map { |texture| [texture.object_id, texture.version] }
        existing = @material_bindings[key]
        if existing&.version == material.version && existing.texture_versions == texture_versions
          return existing.bind_group
        end

        bytes, textures = material_bytes_and_textures(material)
        if existing && existing.buffer.size == bytes.bytesize && existing.texture_versions == texture_versions
          @queue.write_buffer(existing.buffer, 0, bytes)
          existing.version = material.version
          return existing.bind_group
        end

        release_material_binding(existing)
        buffer = @device.create_buffer_with_data(
          label: "stagecraft material",
          data: bytes.empty? ? "\0".b * 16 : bytes,
          usage: %i[uniform copy_dst]
        )
        @stats.increment(:buffers)
        layout = material_layout(material)
        bind_group = @device.create_bind_group(
          layout:,
          entries: material_entries(buffer, textures, material)
        )
        @material_bindings[key] = MaterialBinding.new(
          material.version, texture_versions, buffer, bind_group, signature
        )
        bind_group
      end

      def post_pipeline(format)
        defines = format.to_s.end_with?("_srgb") ? Set.new : Set[:ENCODE_SRGB]
        key = [:post, format, defines.hash]
        @cache.fetch(key) do
          shader = @device.create_shader_module(code: Shaders.compose("tonemap.wgsl", defines:))
          layout = @device.create_pipeline_layout(bind_group_layouts: [post_layout])
          @device.create_render_pipeline(
            label: "stagecraft tonemap",
            layout:,
            vertex: { module: shader, entry_point: "vs_main" },
            primitive: { topology: :triangle_list, cull_mode: :none },
            fragment: {
              module: shader,
              entry_point: "fs_main",
              targets: [{ format: }]
            }
          )
        end
      end

      def post_layout
        @post_layout ||= @device.create_bind_group_layout(
          entries: [
            { binding: 0, visibility: :fragment, texture: { sample_type: :float } },
            { binding: 1, visibility: :fragment, sampler: { type: :filtering } }
          ]
        )
      end

      def dispose
        @cache.clear
        @material_bindings.each_value { |binding| release_material_binding(binding) }
        @material_bindings.clear
        @material_layouts.each_value { |layout| layout.release if layout.respond_to?(:release) }
        @material_layouts.clear
        @post_layout&.release
      end

      private

      def build_pipeline(item, shadow:)
        material = item.mesh.material
        source = if shadow
                   Shaders.compose("shadow.wgsl", defines: item.features)
                 else
                   material_shader_source(material, item.features)
                 end
        shader = @device.create_shader_module(code: source)
        groups = if shadow
                   [@resources.shadow_frame_layout, @resources.empty_layout, @resources.object_layout]
                 else
                   [@resources.frame_layout, material_layout(material), @resources.object_layout]
                 end
        layout = @device.create_pipeline_layout(bind_group_layouts: groups)
        descriptor = {
          label: shadow ? "stagecraft shadow pipeline" : "stagecraft material pipeline",
          layout:,
          vertex: {
            module: shader,
            entry_point: "vs_main",
            buffers: vertex_buffers(item.mesh.geometry, material, shadow:)
          },
          primitive: {
            topology: topology(item.mesh.geometry),
            cull_mode: shadow ? :front : cull_mode(material)
          },
          depth_stencil: {
            format: shadow ? :depth32_float : :depth24_plus,
            depth_write_enabled: shadow || material.depth_write,
            depth_compare: material.depth_test || shadow ? :less : :always,
            depth_bias: shadow ? 2 : 0,
            depth_bias_slope_scale: shadow ? 2.0 : 0.0
          },
          multisample: { count: shadow ? 1 : @sample_count }
        }
        if %i[triangle_strip line_strip].include?(item.mesh.geometry.topology) && item.mesh.geometry.index
          descriptor[:primitive][:strip_index_format] = item.mesh.geometry.index.format
        end
        unless shadow
          descriptor[:fragment] = {
            module: shader,
            entry_point: "fs_main",
            targets: [{ format: :rgba16_float, blend: blend_state(material) }]
          }
        end
        @device.create_render_pipeline(**descriptor)
      end

      def material_shader_source(material, features)
        case material
        when Materials::PBR then Shaders.compose("pbr.wgsl", defines: features)
        when Materials::Unlit then Shaders.compose("unlit.wgsl", defines: features)
        when Materials::Shader then custom_shader_source(material)
        else
          raise Error, "unsupported material #{material.class}"
        end
      end

      def custom_shader_source(material)
        packed = UniformPacker.new.pack(material.uniforms)
        common = Shaders.read("common.wgsl")
        source = material.wgsl.gsub(%r{^\s*//#include\s+["']common\.wgsl["']\s*$}, common)
        source = "#{common}\n#{source}" unless source.include?("struct FrameUniforms")
        declarations = [packed.struct_source, "@group(1) @binding(0) var<uniform> material: MaterialUniforms;"]
        packed.textures.each_with_index do |(name, _texture), index|
          binding = 1 + (index * 2)
          declarations << "@group(1) @binding(#{binding}) var #{name}_sampler: sampler;"
          declarations << "@group(1) @binding(#{binding + 1}) var #{name}: texture_2d<f32>;"
        end
        "#{declarations.join("\n")}\n#{source}"
      end

      def material_layout(material)
        signature = material_layout_signature(material)
        @material_layouts[signature] ||= @device.create_bind_group_layout(
          label: "stagecraft material layout",
          entries: material_layout_entries(material)
        )
      end

      def material_layout_signature(material)
        case material
        when Materials::PBR then :pbr
        when Materials::Unlit then :unlit
        when Materials::Shader
          packed = UniformPacker.new.pack(material.uniforms)
          [:shader, packed.fields.map { |field| [field.name, field.type] }, packed.textures.map(&:first)].hash
        else
          material.class.name
        end
      end

      def material_layout_entries(material)
        base = [{ binding: 0, visibility: %i[vertex fragment], buffer: { type: :uniform } }]
        case material
        when Materials::PBR
          5.times do |index|
            binding = 1 + (index * 2)
            base << { binding:, visibility: :fragment, sampler: { type: :filtering } }
            base << {
              binding: binding + 1,
              visibility: :fragment,
              texture: { sample_type: :float }
            }
          end
        when Materials::Unlit
          base << { binding: 1, visibility: :fragment, sampler: { type: :filtering } }
          base << { binding: 2, visibility: :fragment, texture: { sample_type: :float } }
        when Materials::Shader
          UniformPacker.new.pack(material.uniforms).textures.each_index do |index|
            binding = 1 + (index * 2)
            base << { binding:, visibility: :fragment, sampler: { type: :filtering } }
            base << { binding: binding + 1, visibility: :fragment, texture: { sample_type: :float } }
          end
        end
        base
      end

      def material_bytes_and_textures(material)
        case material
        when Materials::PBR then pbr_bytes_and_textures(material)
        when Materials::Unlit then unlit_bytes_and_textures(material)
        when Materials::Shader
          packed = UniformPacker.new.pack(material.uniforms)
          [packed.bytes, packed.textures.map(&:last)]
        end
      end

      def pbr_bytes_and_textures(material)
        maps = [
          material.base_color_map,
          material.metallic_roughness_map,
          material.normal_map,
          material.occlusion_map,
          material.emissive_map
        ]
        color = material.base_color.to_a
        color[3] *= material.opacity
        bytes = color.pack("e*")
        bytes << [material.metallic, material.roughness, material.normal_scale,
                  material.occlusion_strength].pack("e*")
        bytes << [*material.emissive.to_a.first(3), material.emissive_strength].pack("e*")
        bytes << maps.first(4).map { |map| map ? 1 : 0 }.pack("L<*")
        bytes << [maps[4] ? 1 : 0].pack("L<")
        bytes << [material.alpha_cutoff].pack("e")
        bytes << "\0".b * 8
        bytes << Materials::PBR::UV_SET_ATTRIBUTES.map { |name| material.public_send(name) }
                                                     .first(4).pack("L<*")
        bytes << [material.emissive_uv_set].pack("L<")
        bytes << "\0".b * 12
        Materials::PBR::TRANSFORM_ATTRIBUTES.each do |name|
          bytes << pack_mat3(material.public_send(name))
        end
        fallbacks = [
          @resources.fallback_white,
          @resources.fallback_white,
          @resources.fallback_normal,
          @resources.fallback_white,
          @resources.fallback_black
        ]
        [bytes, resolve_textures(maps, fallbacks)]
      end

      def unlit_bytes_and_textures(material)
        color = material.color.to_a
        color[3] *= material.opacity
        bytes = color.pack("e*")
        bytes << [material.map ? 1 : 0].pack("L<")
        bytes << [material.alpha_cutoff].pack("e")
        bytes << [material.uv_set].pack("L<")
        bytes << "\0".b * 4
        bytes << pack_mat3(material.uv_transform)
        [bytes, resolve_textures([material.map], [@resources.fallback_white])]
      end

      def resolve_textures(textures, fallbacks)
        textures.each_with_index.map do |texture, index|
          texture ? @resource_cache.gpu_texture(texture) : fallbacks[index]
        end
      end

      def material_entries(buffer, textures, material)
        entries = [{ binding: 0, buffer: }]
        return entries if textures.empty?

        if material.is_a?(Materials::PBR)
          textures.each_with_index do |texture, index|
            binding = 1 + (index * 2)
            entries << { binding:, sampler: texture.sampler }
            entries << { binding: binding + 1, texture_view: texture.view }
          end
        elsif material.is_a?(Materials::Unlit)
          entries << { binding: 1, sampler: textures.first.sampler }
          textures.each_with_index { |texture, index| entries << { binding: index + 2, texture_view: texture.view } }
        else
          textures.each_with_index do |texture, index|
            binding = 1 + (index * 2)
            entries << { binding:, sampler: texture.sampler }
            entries << { binding: binding + 1, texture_view: texture.view }
          end
        end
        entries
      end

      def material_textures(material)
        case material
        when Materials::PBR
          Materials::PBR::TEXTURE_ATTRIBUTES.filter_map { |name| material.public_send(name) }
        when Materials::Unlit
          [material.map].compact
        when Materials::Shader
          UniformPacker.new.pack(material.uniforms).textures.map(&:last)
        else
          []
        end
      end

      def vertex_buffers(geometry, material, shadow:)
        names = if shadow
                  %i[position joints weights]
                elsif material.is_a?(Materials::Unlit)
                  %i[position uv uv1 joints weights]
                else
                  ATTRIBUTE_LOCATIONS.keys
                end
        names.filter_map do |name|
          attribute = geometry.attribute(name)
          next unless attribute

          {
            array_stride: FORMAT_SIZES.fetch(attribute.format),
            step_mode: :vertex,
            attributes: [{
              format: attribute.format,
              offset: 0,
              shader_location: ATTRIBUTE_LOCATIONS.fetch(name)
            }]
          }
        end
      end

      def topology(geometry)
        geometry.topology
      end

      def pack_mat3(matrix)
        values = matrix.to_a
        [values[0], values[1], values[2], 0.0,
         values[3], values[4], values[5], 0.0,
         values[6], values[7], values[8], 0.0].pack("e*")
      end

      def cull_mode(material)
        { front: :back, back: :front, double: :none }.fetch(material.side)
      end

      def blend_state(material)
        return nil unless material.transparent?
        return material.blend if material.blend.is_a?(Hash)

        case material.blend
        when :additive
          {
            color: { src_factor: :src_alpha, dst_factor: :one },
            alpha: { src_factor: :one, dst_factor: :one }
          }
        when :multiply
          {
            color: { src_factor: :dst, dst_factor: :zero },
            alpha: { src_factor: :one, dst_factor: :one_minus_src_alpha }
          }
        else
          {
            color: { src_factor: :src_alpha, dst_factor: :one_minus_src_alpha },
            alpha: { src_factor: :one, dst_factor: :one_minus_src_alpha }
          }
        end
      end

      def release_material_binding(binding)
        return unless binding

        binding.bind_group.release if binding.bind_group.respond_to?(:release)
        binding.buffer.destroy if binding.buffer.respond_to?(:destroy)
        binding.buffer.release if binding.buffer.respond_to?(:release)
        @stats.decrement(:buffers)
      end
    end
  end
end
