# frozen_string_literal: true

module Stagecraft
  class Renderer
    attr_reader :device, :queue, :surface_format, :stats, :width, :height, :sample_count

    def self.offscreen(width:, height:, msaa: 1, **options)
      new(width:, height:, msaa:, **options)
    end

    def initialize(window: nil, width: 800, height: 600, msaa: 4, device: nil, queue: nil,
                   surface: nil, backend: nil)
      @backend = backend
      @window = window
      @width = Integer(width)
      @height = Integer(height)
      @sample_count = Integer(msaa)
      @stats = Stats.new
      @after_render_callbacks = []
      @disposed = false
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if backend

      @context = GPUContext.new(window:, width:, height:, device:, queue:, surface:)
      @device = @context.device
      @queue = @context.queue
      @surface_format = @context.surface_format
      @resources = FrameResources.new(context: @context, stats:, sample_count:)
      @sample_count = @resources.sample_count
      @resource_cache = ResourceCache.new(device: @device, queue: @queue, stats:)
      @pipelines = PipelineFactory.new(
        device: @device, queue: @queue, resources: @resources, resource_cache: @resource_cache,
        stats:, sample_count: @sample_count
      )
      create_post_resources
    end

    def render(scene, camera)
      ensure_alive!
      resize_from_window
      list = RenderList.new(scene, camera)
      update_stats(list)
      if @backend
        frame = record_frame(list, camera)
        report_debug_stats
        return frame
      end

      light, light_vp = shadow_light_and_matrix(list)
      @resources.resize_shadow(light.shadow.map_size) if light
      ordered_items = list.items
      @resources.begin_frame(
        ordered_items,
        camera:,
        ambient: list.ambient,
        lights: prioritized_lights(list.lights, light),
        light_vp:,
        time: elapsed_time
      )
      encoder = device.create_command_encoder(label: "stagecraft frame")
      encode_shadow_pass(encoder, light ? ordered_items : [])
      encode_main_pass(encoder, ordered_items, scene)
      @after_render_callbacks.each { |callback| callback.call(encoder, @resources.hdr_view) }
      target_texture, target_view = @resources.frame_target
      encode_post_pass(encoder, target_view)
      queue.submit([encoder.finish])
      @context.present
      @resource_cache.advance_frame
      frame = Frame.new(
        texture: target_texture,
        width:,
        height:,
        device:,
        queue:,
        readable: @context.surface.nil?
      )
      report_debug_stats
      frame
    end

    def resize(width, height)
      ensure_alive!
      @width = [Integer(width), 1].max
      @height = [Integer(height), 1].max
      return self if @backend
      return self unless @context.resize(@width, @height)

      @resources.resize(@width, @height)
      create_post_resources
      self
    end

    def on_after_render(&block)
      @after_render_callbacks << block
      self
    end

    def dispose
      return self if @disposed

      if @resource_cache&.live_count&.positive? && ENV["STAGECRAFT_DEBUG"] == "1"
        warn "Stagecraft renderer disposed with #{@resource_cache.live_count} live CPU resources"
      end
      release_post_resources
      @pipelines&.dispose
      @resource_cache&.dispose_all
      @resources&.dispose
      @context&.dispose
      @disposed = true
      self
    end

    def disposed?
      @disposed
    end

    private

    def resize_from_window
      return unless @window&.respond_to?(:drawable_size)

      next_width, next_height = @window.drawable_size
      resize(next_width, next_height) if next_width.positive? && next_height.positive?
    end

    def update_stats(list)
      stats.reset_frame!
      stats.increment(:visible_objects, list.items.length)
      stats.increment(:culled_objects, list.culled_count)
    end

    def record_frame(list, camera)
      @backend.begin_frame(camera:) if @backend.respond_to?(:begin_frame)
      list.items.each do |item|
        @backend.draw(
          mesh: item.mesh,
          features: item.features,
          depth: item.depth,
          pipeline_key: [
            item.mesh.material.class,
            Features.bits(item.features),
            Features.vertex_layout_id(item.mesh.geometry)
          ]
        )
        track_draw(item.mesh.geometry)
      end
      @backend.end_frame if @backend.respond_to?(:end_frame)
      nil
    end

    def shadow_light_and_matrix(list)
      light = list.lights.find { |candidate| candidate.is_a?(Lights::Directional) && candidate.cast_shadow }
      return [nil, Larb::Mat4.identity] unless light

      config = light.shadow
      eye = light.world_position
      target = eye + light.direction
      view = Larb::Mat4.look_at(eye, target, Larb::Vec3.up)
      extent = config.extent
      projection = Cameras::Orthographic.new(
        left: -extent, right: extent, top: extent, bottom: -extent,
        near: config.near, far: config.far
      ).projection_matrix
      [light, projection * view]
    end

    def prioritized_lights(lights, shadow_light)
      return lights unless shadow_light

      [shadow_light, *lights.reject { |light| light.equal?(shadow_light) }]
    end

    def encode_shadow_pass(encoder, items)
      pass = encoder.begin_render_pass(
        label: "stagecraft shadow",
        color_attachments: [],
        depth_stencil_attachment: {
          view: @resources.shadow_view,
          depth_load_op: :clear,
          depth_store_op: :store,
          depth_clear_value: 1.0
        }
      )
      items.each_with_index do |item, index|
        next unless item.mesh.cast_shadow

        draw_item(pass, item, index, shadow: true)
      end
      pass.end_pass
    end

    def encode_main_pass(encoder, items, scene)
      clear = scene.background || Color.new(0.0)
      attachment = @resources.main_color_attachment.merge(
        clear_value: { r: clear.r, g: clear.g, b: clear.b, a: clear.a }
      )
      pass = encoder.begin_render_pass(
        label: "stagecraft main",
        color_attachments: [attachment],
        depth_stencil_attachment: {
          view: @resources.depth_view,
          depth_load_op: :clear,
          depth_store_op: :store,
          depth_clear_value: 1.0
        }
      )
      items.each_with_index { |item, index| draw_item(pass, item, index) }
      pass.end_pass
    end

    def draw_item(pass, item, index, shadow: false)
      geometry = @resource_cache.gpu_geometry(item.mesh.geometry)
      pass.set_pipeline(@pipelines.pipeline_for(item, shadow:))
      pass.set_bind_group(0, shadow ? @resources.shadow_frame_group : @resources.frame_group)
      if shadow
        pass.set_bind_group(1, @resources.empty_group)
      else
        pass.set_bind_group(1, @pipelines.material_binding(item.mesh.material, item.features))
      end
      pass.set_bind_group(
        2,
        @resources.object_group_for(item.mesh),
        dynamic_offsets: [@resources.object_offset(index)]
      )
      bind_vertex_buffers(pass, item.mesh.geometry, geometry, item.mesh.material, shadow:)
      if geometry.index_buffer
        pass.set_index_buffer(geometry.index_buffer, geometry.index_format)
        pass.draw_indexed(geometry.index_count)
      else
        pass.draw(geometry.vertex_count)
      end
      track_draw(item.mesh.geometry) unless shadow
    end

    def bind_vertex_buffers(pass, geometry, gpu_geometry, material, shadow:)
      names = if shadow
                %i[position joints weights]
              elsif material.is_a?(Materials::Unlit)
                %i[position uv joints weights]
              else
                PipelineFactory::ATTRIBUTE_LOCATIONS.keys
              end
      slot = 0
      names.each do |name|
        next unless geometry.attribute(name)

        pass.set_vertex_buffer(slot, gpu_geometry.vertex_buffers.fetch(name))
        slot += 1
      end
    end

    def track_draw(geometry)
      stats.increment(:draw_calls)
      count = geometry.index&.count || geometry.attribute(:position).count
      triangles = case geometry.topology
                  when :triangle_list then count / 3
                  when :triangle_strip then [count - 2, 0].max
                  else 0
                  end
      stats.increment(:triangles, triangles)
    end

    def create_post_resources
      return unless @resources

      release_post_resources
      @post_sampler = device.create_sampler(mag_filter: :linear, min_filter: :linear)
      @post_group = device.create_bind_group(
        layout: @pipelines.post_layout,
        entries: [
          { binding: 0, texture_view: @resources.hdr_view },
          { binding: 1, sampler: @post_sampler }
        ]
      )
      @post_pipeline = @pipelines.post_pipeline(surface_format)
    end

    def encode_post_pass(encoder, target_view)
      pass = encoder.begin_render_pass(
        label: "stagecraft post",
        color_attachments: [{ view: target_view, load_op: :clear, store_op: :store }]
      )
      pass.set_pipeline(@post_pipeline)
      pass.set_bind_group(0, @post_group)
      pass.draw(3)
      pass.end_pass
    end

    def release_post_resources
      @post_group&.release
      @post_sampler&.release
      @post_group = @post_sampler = nil
    end

    def elapsed_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
    end

    def report_debug_stats
      return unless ENV["STAGECRAFT_DEBUG"] == "1"

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if @last_debug_report && now - @last_debug_report < 1.0

      warn "Stagecraft #{stats}"
      @last_debug_report = now
    end

    def ensure_alive!
      raise DisposedError, "renderer has been disposed" if disposed?
    end
  end
end
