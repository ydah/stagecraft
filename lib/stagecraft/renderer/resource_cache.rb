# frozen_string_literal: true

module Stagecraft
  class Renderer
    class ResourceCache
      GPUGeometry = Data.define(:vertex_buffers, :index_buffer, :index_format, :index_count, :vertex_count, :layout_id)
      GPUTexture = Data.define(:texture, :view, :sampler)
      Entry = Struct.new(:owner, :version, :resource)

      attr_reader :frame

      def initialize(device:, queue:, stats:, in_flight_frames: 3)
        @device = device
        @queue = queue
        @stats = stats
        @in_flight_frames = in_flight_frames
        @geometries = {}
        @textures = {}
        @dispose_queue = []
        @registered = {}
        @frame = 0
      end

      def gpu_geometry(geometry)
        raise DisposedError, "cannot upload disposed geometry" if geometry.disposed?

        existing = @geometries[geometry.object_id]
        if existing&.owner&.equal?(geometry) && existing.version == geometry.version
          return existing.resource
        end

        schedule_resource(existing.resource) if existing
        resource = upload_geometry(geometry)
        @geometries[geometry.object_id] = Entry.new(geometry, geometry.version, resource)
        register_disposal(geometry)
        resource
      end

      def gpu_texture(texture)
        raise DisposedError, "cannot upload disposed texture" if texture.disposed?

        existing = @textures[texture.object_id]
        if existing&.owner&.equal?(texture) && existing.version == texture.version
          return existing.resource
        end

        schedule_resource(existing.resource) if existing
        resource = upload_texture(texture)
        @textures[texture.object_id] = Entry.new(texture, texture.version, resource)
        register_disposal(texture)
        resource
      end

      def schedule_dispose(cpu_object)
        entry = delete_owned_entry(@geometries, cpu_object) ||
                delete_owned_entry(@textures, cpu_object)
        schedule_resource(entry.resource) if entry
        @registered.delete(cpu_object.object_id)
        self
      end

      def advance_frame
        @frame += 1
        ready, @dispose_queue = @dispose_queue.partition { |due, _resource| due <= frame }
        ready.each { |_due, resource| destroy_resource(resource) }
        self
      end

      def dispose_all
        resources = @geometries.values.concat(@textures.values).map(&:resource)
        resources.concat(@dispose_queue.map(&:last))
        resources.each { |resource| destroy_resource(resource) }
        @geometries.clear
        @textures.clear
        @dispose_queue.clear
        @registered.clear
        self
      end

      def live_count
        @geometries.length + @textures.length
      end

      private

      def upload_geometry(geometry)
        buffers = geometry.attributes.to_h do |name, attribute|
          buffer = @device.create_buffer_with_data(
            label: "stagecraft #{name}",
            data: attribute.data,
            usage: %i[vertex copy_dst]
          )
          @stats.increment(:buffers)
          [name, buffer]
        end
        index_buffer = if geometry.index
                         @stats.increment(:buffers)
                         @device.create_buffer_with_data(
                           label: "stagecraft index",
                           data: geometry.index.data,
                           usage: %i[index copy_dst]
                         )
                       end
        GPUGeometry.new(
          vertex_buffers: buffers.freeze,
          index_buffer:,
          index_format: geometry.index&.format,
          index_count: geometry.index&.count,
          vertex_count: geometry.attribute(:position).count,
          layout_id: Features.vertex_layout_id(geometry)
        )
      end

      def upload_texture(texture)
        require "texel/wgpu"
        raise Error, "texture has no image" unless texture.image

        image = texture.image
        if texture.color_space && image.color_space != texture.color_space
          image = image.dup_with(color_space: texture.color_space)
        end
        gpu_texture = Texel::WGPU.upload(image, device: @device, queue: @queue)
        sampler_state = texture.sampler
        sampler = @device.create_sampler(
          address_mode_u: sampler_state.wrap_u,
          address_mode_v: sampler_state.wrap_v,
          address_mode_w: sampler_state.wrap_w,
          mag_filter: sampler_state.mag_filter,
          min_filter: sampler_state.min_filter,
          mipmap_filter: sampler_state.mipmap_filter,
          lod_min_clamp: sampler_state.lod_min,
          lod_max_clamp: sampler_state.lod_max,
          compare: sampler_state.compare,
          max_anisotropy: sampler_state.max_anisotropy
        )
        @stats.increment(:textures)
        GPUTexture.new(texture: gpu_texture, view: gpu_texture.create_view, sampler:)
      end

      def register_disposal(object)
        return if @registered[object.object_id]

        @registered[object.object_id] = true
        object.on_dispose { |disposed| schedule_dispose(disposed) }
      end

      def delete_owned_entry(collection, owner)
        entry = collection[owner.object_id]
        return unless entry&.owner&.equal?(owner)

        collection.delete(owner.object_id)
      end

      def schedule_resource(resource)
        @dispose_queue << [frame + @in_flight_frames, resource]
      end

      def destroy_resource(resource)
        case resource
        when GPUGeometry
          [*resource.vertex_buffers.values, resource.index_buffer].compact.each do |buffer|
            buffer.destroy if buffer.respond_to?(:destroy)
            buffer.release if buffer.respond_to?(:release)
            @stats.decrement(:buffers)
          end
        when GPUTexture
          resource.sampler.release if resource.sampler.respond_to?(:release)
          resource.view.release if resource.view.respond_to?(:release)
          resource.texture.destroy if resource.texture.respond_to?(:destroy)
          resource.texture.release if resource.texture.respond_to?(:release)
          @stats.decrement(:textures)
        end
      end
    end
  end
end
