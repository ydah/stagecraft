# frozen_string_literal: true

module Stagecraft
  class Renderer
    class FrameResources
      SkinBinding = Struct.new(:mesh, :skin, :buffer, :bind_group)
      OBJECT_SLOT_SIZE = 256
      OBJECT_DATA_SIZE = 144
      FRAMES_IN_FLIGHT = 3
      LIGHT_SIZE = 80
      GUARANTEED_SAMPLE_COUNTS = [1, 4].freeze

      attr_reader :device, :queue, :stats, :frame_layout, :object_layout, :empty_layout, :empty_group,
                  :shadow_frame_layout, :frame_group, :shadow_frame_group, :object_group,
                  :hdr_texture, :hdr_view, :depth_texture, :depth_view, :shadow_texture,
                  :shadow_view, :fallback_white, :fallback_black, :fallback_normal,
                  :output_texture, :output_view, :width, :height, :sample_count

      def self.guaranteed_sample_count(requested)
        value = Integer(requested)
        GUARANTEED_SAMPLE_COUNTS.reverse.find { |count| count <= value } ||
          GUARANTEED_SAMPLE_COUNTS.first
      end

      def initialize(context:, stats:, sample_count:)
        @context = context
        @device = context.device
        @queue = context.queue
        @stats = stats
        @sample_count = self.class.guaranteed_sample_count(sample_count)
        @frame_number = 0
        @object_capacity = 1
        @light_capacity = 1
        @skin_bindings = {}
        create_layouts
        create_buffers
        create_shadow_resources
        create_fallback_textures
        resize(context.width, context.height)
      rescue StandardError
        dispose_after_failed_initialization
        raise
      end

      def resize(width, height)
        @width = Integer(width)
        @height = Integer(height)
        release_attachments
        create_hdr_attachments
        create_output_attachment unless @context.surface
        self
      end

      def begin_frame(items, camera:, ambient:, lights:, light_vp:, time:)
        ensure_object_capacity(items.length)
        ensure_light_capacity(lights.length)
        write_frame(camera:, ambient:, lights:, light_vp:, time:)
        write_objects(items)
        write_skins(items)
        @frame_number += 1
        self
      end

      def object_offset(index)
        frame_slot = (@frame_number - 1) % FRAMES_IN_FLIGHT
        (frame_slot * @object_capacity * OBJECT_SLOT_SIZE) + (index * OBJECT_SLOT_SIZE)
      end

      def object_group_for(mesh)
        mesh.skin ? @skin_bindings.fetch(mesh.object_id).bind_group : object_group
      end

      def resize_shadow(map_size)
        next_size = Integer(map_size)
        return self if next_size == @shadow_size

        release_resource(@shadow_view)
        destroy_texture(@shadow_texture)
        create_shadow_texture(next_size)
        recreate_frame_groups
        self
      end

      def main_color_attachment
        if sample_count > 1
          {
            view: @hdr_msaa_view,
            resolve_target: hdr_view,
            load_op: :clear,
            store_op: :discard
          }
        else
          { view: hdr_view, load_op: :clear, store_op: :store }
        end
      end

      def frame_target
        return [output_texture, output_view] unless @context.surface

        @context.current_target
      end

      def dispose
        release_attachments
        release_resource(@shadow_sampler, @shadow_view)
        destroy_texture(@shadow_texture)
        [fallback_white, fallback_black, fallback_normal].compact.each do |resource|
          release_gpu_texture(resource)
        end
        release_resource(@frame_group, @shadow_frame_group, @object_group, @empty_group)
        @skin_bindings.each_value do |binding|
          release_resource(binding.bind_group)
          destroy_buffer(binding.buffer)
        end
        @skin_bindings.clear
        [@frame_buffer, @lights_buffer, @object_buffer, @joint_buffer].compact.each do |buffer|
          destroy_buffer(buffer)
        end
        release_resource(frame_layout, object_layout, empty_layout, shadow_frame_layout)
      end

      private

      def dispose_after_failed_initialization
        dispose
      rescue StandardError
        nil
      end

      def create_layouts
        @frame_layout = device.create_bind_group_layout(
          label: "stagecraft frame layout",
          entries: [
            { binding: 0, visibility: %i[vertex fragment], buffer: { type: :uniform } },
            { binding: 1, visibility: :fragment, buffer: { type: :read_only_storage } },
            { binding: 2, visibility: :fragment, texture: { sample_type: :depth } },
            { binding: 3, visibility: :fragment, sampler: { type: :comparison } }
          ]
        )
        @shadow_frame_layout = device.create_bind_group_layout(
          entries: [{ binding: 0, visibility: :vertex, buffer: { type: :uniform } }]
        )
        @object_layout = device.create_bind_group_layout(
          label: "stagecraft object layout",
          entries: [
            {
              binding: 0,
              visibility: %i[vertex fragment],
              buffer: { type: :uniform, has_dynamic_offset: true, min_binding_size: OBJECT_DATA_SIZE }
            },
            { binding: 1, visibility: :vertex, buffer: { type: :read_only_storage } }
          ]
        )
        @empty_layout = device.create_bind_group_layout(entries: [])
        @empty_group = device.create_bind_group(layout: empty_layout, entries: [])
      end

      def create_buffers
        @frame_buffer = device.create_buffer(
          label: "stagecraft frame uniforms", size: 256, usage: %i[uniform copy_dst]
        )
        stats.increment(:buffers)
        @lights_buffer = device.create_buffer(
          label: "stagecraft lights", size: LIGHT_SIZE, usage: %i[storage copy_dst]
        )
        stats.increment(:buffers)
        @joint_buffer = device.create_buffer(
          label: "stagecraft empty joints", size: 64, usage: %i[storage copy_dst]
        )
        stats.increment(:buffers)
        @object_buffer = create_object_buffer
        stats.increment(:buffers)
      end

      def create_shadow_resources
        create_shadow_texture(2_048)
        @shadow_sampler = device.create_sampler(
          compare: :less_equal,
          mag_filter: :linear,
          min_filter: :linear
        )
        recreate_frame_groups
      end

      def create_shadow_texture(size)
        @shadow_size = Integer(size)
        @shadow_texture = device.create_texture(
          label: "stagecraft shadow map",
          size: { width: @shadow_size, height: @shadow_size, depth_or_array_layers: 1 },
          format: :depth32_float,
          usage: %i[render_attachment texture_binding]
        )
        @shadow_view = shadow_texture.create_view
      end

      def create_fallback_textures
        @fallback_white = solid_texture([255, 255, 255, 255], srgb: true)
        @fallback_black = solid_texture([0, 0, 0, 255], srgb: true)
        @fallback_normal = solid_texture([128, 128, 255, 255], srgb: false)
      end

      def solid_texture(rgba, srgb:)
        texture = device.create_texture(
          size: { width: 1, height: 1, depth_or_array_layers: 1 },
          format: srgb ? :rgba8_unorm_srgb : :rgba8_unorm,
          usage: %i[texture_binding copy_dst]
        )
        queue.write_texture(
          destination: { texture: },
          data: rgba.pack("C*"),
          data_layout: { bytes_per_row: 4, rows_per_image: 1 },
          size: { width: 1, height: 1, depth_or_array_layers: 1 }
        )
        sampler = device.create_sampler(mag_filter: :linear, min_filter: :linear, mipmap_filter: :linear)
        stats.increment(:textures)
        ResourceCache::GPUTexture.new(texture:, view: texture.create_view, sampler:)
      end

      def create_hdr_attachments
        @hdr_texture = device.create_texture(
          label: "stagecraft hdr",
          size: extent,
          format: :rgba16_float,
          usage: %i[render_attachment texture_binding copy_src]
        )
        @hdr_view = hdr_texture.create_view
        if sample_count > 1
          @hdr_msaa_texture = device.create_texture(
            label: "stagecraft hdr msaa",
            size: extent,
            format: :rgba16_float,
            usage: :render_attachment,
            sample_count:
          )
          @hdr_msaa_view = @hdr_msaa_texture.create_view
        end
        @depth_texture = device.create_texture(
          label: "stagecraft depth",
          size: extent,
          format: :depth24_plus,
          usage: :render_attachment,
          sample_count:
        )
        @depth_view = depth_texture.create_view
      end

      def create_output_attachment
        @output_texture = device.create_texture(
          label: "stagecraft output",
          size: extent,
          format: @context.surface_format,
          usage: %i[render_attachment texture_binding copy_src]
        )
        @output_view = output_texture.create_view
      end

      def ensure_object_capacity(count)
        return if count <= @object_capacity

        release_resource(@object_group)
        destroy_buffer(@object_buffer)
        @object_capacity *= 2 while @object_capacity < count
        @object_buffer = create_object_buffer
        stats.increment(:buffers)
        recreate_object_group
      end

      def ensure_light_capacity(count)
        return if count <= @light_capacity

        destroy_buffer(@lights_buffer)
        @light_capacity *= 2 while @light_capacity < count
        @lights_buffer = device.create_buffer(
          label: "stagecraft lights",
          size: @light_capacity * LIGHT_SIZE,
          usage: %i[storage copy_dst]
        )
        stats.increment(:buffers)
        recreate_frame_groups
      end

      def create_object_buffer
        device.create_buffer(
          label: "stagecraft object uniforms",
          size: @object_capacity * OBJECT_SLOT_SIZE * FRAMES_IN_FLIGHT,
          usage: %i[uniform copy_dst]
        )
      end

      def recreate_frame_groups
        release_resource(@frame_group, @shadow_frame_group)
        @frame_group = device.create_bind_group(
          label: "stagecraft frame bind group",
          layout: frame_layout,
          entries: [
            { binding: 0, buffer: @frame_buffer, size: 160 },
            { binding: 1, buffer: @lights_buffer },
            { binding: 2, texture_view: shadow_view },
            { binding: 3, sampler: @shadow_sampler }
          ]
        )
        @shadow_frame_group = device.create_bind_group(
          layout: shadow_frame_layout,
          entries: [{ binding: 0, buffer: @frame_buffer, size: 160 }]
        )
        recreate_object_group
      end

      def recreate_object_group
        release_resource(@object_group)
        @object_group = device.create_bind_group(
          label: "stagecraft object bind group",
          layout: object_layout,
          entries: [
            { binding: 0, buffer: @object_buffer, size: OBJECT_DATA_SIZE },
            { binding: 1, buffer: @joint_buffer }
          ]
        )
        @skin_bindings.each_value do |binding|
          release_resource(binding.bind_group)
          binding.bind_group = create_object_group(binding.buffer)
        end
      end

      def create_object_group(joint_buffer)
        device.create_bind_group(
          label: "stagecraft skinned object bind group",
          layout: object_layout,
          entries: [
            { binding: 0, buffer: @object_buffer, size: OBJECT_DATA_SIZE },
            { binding: 1, buffer: joint_buffer }
          ]
        )
      end

      def write_frame(camera:, ambient:, lights:, light_vp:, time:)
        bytes = String.new(capacity: 160, encoding: Encoding::BINARY)
        bytes << camera.view_projection_matrix.to_a.pack("e*")
        bytes << [*camera.world_position.to_a, time.to_f].pack("e*")
        bytes << ambient.to_a.pack("e*")
        bytes << [lights.length].pack("L<")
        bytes << light_vp.to_a.pack("e*")
        queue.write_buffer(@frame_buffer, 0, bytes)
        return if lights.empty?

        queue.write_buffer(@lights_buffer, 0, pack_lights(lights))
      end

      def pack_lights(lights)
        lights.map do |light|
          bytes = "\0".b * LIGHT_SIZE
          kind = { Lights::Directional => 0, Lights::Point => 1, Lights::Spot => 2 }.fetch(light.class, 0)
          bytes[0, 4] = [kind].pack("L<")
          color = light.color.to_a.first(3).map { |component| component * light.intensity }
          bytes[16, 12] = color.pack("e*")
          bytes[32, 12] = light.world_position.to_a.pack("e*")
          bytes[48, 12] = light.direction.to_a.pack("e*")
          range = light.respond_to?(:range) ? light.range : 0.0
          bytes[60, 4] = [range.finite? ? range : 3.4e38].pack("e")
          cone = light.is_a?(Lights::Spot) ? [Math.cos(light.inner_angle), Math.cos(light.outer_angle)] : [1.0, -1.0]
          bytes[64, 8] = cone.pack("e*")
          bytes
        end.join
      end

      def write_objects(items)
        return if items.empty?

        frame_slot = @frame_number % FRAMES_IN_FLIGHT
        bytes = "\0".b * (@object_capacity * OBJECT_SLOT_SIZE)
        items.each_with_index do |item, index|
          offset = index * OBJECT_SLOT_SIZE
          model = item.mesh.world_matrix
          bytes[offset, 64] = model.to_a.pack("e*")
          normal = model.inverse.transpose
          bytes[offset + 64, 64] = normal.to_a.pack("e*")
        rescue StandardError
          bytes[offset + 64, 64] = Larb::Mat4.identity.to_a.pack("e*")
        ensure
          bytes[offset + 128, 4] = [item.mesh.receive_shadow ? 1 : 0].pack("L<")
        end
        queue.write_buffer(
          @object_buffer,
          frame_slot * @object_capacity * OBJECT_SLOT_SIZE,
          bytes
        )
      end

      def write_skins(items)
        prune_skin_bindings(items)
        items.each do |item|
          mesh = item.mesh
          next unless mesh.skin

          binding = @skin_bindings[mesh.object_id]
          if !binding || !binding.mesh.equal?(mesh) || !binding.skin.equal?(mesh.skin)
            if binding
              release_resource(binding.bind_group)
              destroy_buffer(binding.buffer)
            end
            size = [mesh.skin.joints.length, 1].max * 64
            buffer = device.create_buffer(
              label: "stagecraft joint matrices",
              size:,
              usage: %i[storage copy_dst]
            )
            stats.increment(:buffers)
            binding = SkinBinding.new(mesh, mesh.skin, buffer, create_object_group(buffer))
            @skin_bindings[mesh.object_id] = binding
          end
          matrices = mesh.skin.joint_matrices(mesh)
          bytes = matrices.empty? ? Larb::Mat4.identity.to_a.pack("e*") :
                                    matrices.flat_map(&:to_a).pack("e*")
          queue.write_buffer(binding.buffer, 0, bytes)
        end
      end

      def prune_skin_bindings(items)
        active = items.filter_map do |item|
          [item.mesh.object_id, item.mesh] if item.mesh.skin
        end.to_h
        @skin_bindings.delete_if do |object_id, binding|
          next false if active[object_id]&.equal?(binding.mesh)

          release_resource(binding.bind_group)
          destroy_buffer(binding.buffer)
          true
        end
      end

      def extent
        { width:, height:, depth_or_array_layers: 1 }
      end

      def release_attachments
        release_resource(@hdr_view, @hdr_msaa_view, @depth_view, @output_view)
        [@hdr_texture, @hdr_msaa_texture, @depth_texture, @output_texture].compact.each do |texture|
          destroy_texture(texture)
        end
        @hdr_texture = @hdr_view = @hdr_msaa_texture = @hdr_msaa_view = nil
        @depth_texture = @depth_view = @output_texture = @output_view = nil
      end

      def release_gpu_texture(resource)
        resource.view.release if resource.view.respond_to?(:release)
        resource.sampler.release if resource.sampler.respond_to?(:release)
        destroy_texture(resource.texture)
        stats.decrement(:textures)
      end

      def destroy_texture(texture)
        texture.destroy if texture.respond_to?(:destroy)
        texture.release if texture.respond_to?(:release)
      end

      def destroy_buffer(buffer)
        buffer.destroy if buffer.respond_to?(:destroy)
        buffer.release if buffer.respond_to?(:release)
        stats.decrement(:buffers)
      end

      def release_resource(*resources)
        resources.compact.each { |resource| resource.release if resource.respond_to?(:release) }
      end
    end
  end
end
