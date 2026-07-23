# frozen_string_literal: true

module Stagecraft
  class Renderer
    class RenderList
      Item = Data.define(:mesh, :depth, :features)

      attr_reader :opaque, :transparent, :lights, :ambient, :culled_count

      def initialize(scene, camera)
        @opaque = []
        @transparent = []
        @lights = []
        @ambient = Larb::Vec3.new
        @culled_count = 0
        @camera = camera
        @frustum = Bounding::Frustum.from_matrix(camera.view_projection_matrix)
        collect(scene, true)
        sort!
      end

      def items
        [*opaque, *transparent]
      end

      private

      def collect(node, inherited_visibility)
        visible = inherited_visibility && node.visible
        node.world_matrix
        collect_visible(node) if visible
        node.children.each { |child| collect(child, visible) }
      end

      def collect_visible(node)
        case node
        when Mesh then collect_mesh(node)
        when Lights::Ambient then collect_ambient(node)
        when Lights::Light then lights << node
        end
      end

      def collect_mesh(mesh)
        if mesh.frustum_culled && !visible_in_frustum?(mesh)
          @culled_count += 1
          return
        end

        camera_position = @camera.view_matrix * mesh.world_position.to_vec4(1.0)
        item = Item.new(mesh:, depth: -camera_position.z, features: Features.for(mesh))
        mesh.material.transparent? ? transparent << item : opaque << item
      end

      def collect_ambient(light)
        color = light.color.to_larb.to_vec3 * light.intensity
        @ambient = ambient + color
      end

      def visible_in_frustum?(mesh)
        sphere = mesh.geometry.bounding_sphere.transform(mesh.world_matrix)
        @frustum.intersects_sphere?(sphere)
      end

      def sort!
        opaque.sort_by! do |item|
          [pipeline_signature(item), item.mesh.material.object_id, item.depth]
        end
        transparent.sort_by! { |item| [item.mesh.render_order, -item.depth] }
      end

      def pipeline_signature(item)
        [
          item.mesh.material.class.name,
          Features.bits(item.features),
          Features.vertex_layout_id(item.mesh.geometry)
        ].hash
      end
    end
  end
end
