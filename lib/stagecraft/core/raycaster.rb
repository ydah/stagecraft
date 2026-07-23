# frozen_string_literal: true

module Stagecraft
  class Raycaster
    Hit = Data.define(:object, :distance, :point)

    attr_reader :origin, :direction, :near, :far

    def initialize(origin: Larb::Vec3.new, direction: Larb::Vec3.forward, near: 0.0, far: Float::INFINITY)
      @near = Float(near)
      @far = Float(far)
      raise ArgumentError, "ray near distance cannot be negative" if @near.negative?
      raise ArgumentError, "ray far distance must not be less than near" if @far < @near

      set(origin, direction)
    end

    def set(origin, direction)
      @origin = vector(origin)
      value = vector(direction)
      raise ArgumentError, "ray direction cannot be zero" if value.length.zero?

      @direction = value.normalize
      self
    end

    def set_from_camera(ndc_x, ndc_y, camera)
      inverse = camera.view_projection_matrix.inverse
      near_point = unproject(inverse, ndc_x, ndc_y, 0.0)
      far_point = unproject(inverse, ndc_x, ndc_y, 1.0)
      ray_origin = camera.is_a?(Cameras::Perspective) ? camera.world_position : near_point
      set(ray_origin, far_point - ray_origin)
    end

    def intersect(root, recursive: true)
      nodes = recursive ? root.traverse : [root]
      nodes.filter_map { |node| intersect_mesh(node) }.sort_by(&:distance)
    end

    private

    def unproject(matrix, x, y, z)
      value = matrix * Larb::Vec4.new(x, y, z, 1.0)
      value.perspective_divide
    end

    def vector(value)
      source = value.respond_to?(:to_larb) ? value.to_larb : value
      Larb::Vec3.new(*source.to_a)
    end

    def intersect_mesh(node)
      return unless node.is_a?(Mesh) && node.visible

      sphere = node.geometry.bounding_sphere.transform(node.world_matrix)
      distance = sphere.intersects_ray?(origin, direction)
      return unless distance && distance >= near && distance <= far

      Hit.new(object: node, distance:, point: origin + (direction * distance))
    end
  end
end
