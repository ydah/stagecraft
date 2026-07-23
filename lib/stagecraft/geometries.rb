# frozen_string_literal: true

module Stagecraft
  module Geometries
    module_function

    def box(width = 1.0, height = 1.0, depth = 1.0, **dimensions)
      width = dimensions.delete(:width) || width
      height = dimensions.delete(:height) || height
      depth = dimensions.delete(:depth) || depth
      reject_unknown_options!(dimensions)
      half = [width, height, depth].map { |value| Float(value) / 2.0 }
      faces = [
        [[1, 0, 0], [[half[0], -half[1], half[2]], [half[0], -half[1], -half[2]], [half[0], half[1], -half[2]], [half[0], half[1], half[2]]]],
        [[-1, 0, 0], [[-half[0], -half[1], -half[2]], [-half[0], -half[1], half[2]], [-half[0], half[1], half[2]], [-half[0], half[1], -half[2]]]],
        [[0, 1, 0], [[-half[0], half[1], half[2]], [half[0], half[1], half[2]], [half[0], half[1], -half[2]], [-half[0], half[1], -half[2]]]],
        [[0, -1, 0], [[-half[0], -half[1], -half[2]], [half[0], -half[1], -half[2]], [half[0], -half[1], half[2]], [-half[0], -half[1], half[2]]]],
        [[0, 0, 1], [[-half[0], -half[1], half[2]], [half[0], -half[1], half[2]], [half[0], half[1], half[2]], [-half[0], half[1], half[2]]]],
        [[0, 0, -1], [[half[0], -half[1], -half[2]], [-half[0], -half[1], -half[2]], [-half[0], half[1], -half[2]], [half[0], half[1], -half[2]]]]
      ]
      positions = []
      normals = []
      uvs = []
      indices = []
      faces.each_with_index do |(normal, vertices), face_index|
        positions.concat(vertices.flatten)
        normals.concat(normal * 4)
        uvs.concat([0, 0, 1, 0, 1, 1, 0, 1])
        base = face_index * 4
        indices.concat([base, base + 1, base + 2, base, base + 2, base + 3])
      end
      build(positions, normals, uvs, indices)
    end

    def plane(width = 1.0, height = 1.0, width_segments: 1, height_segments: 1, **dimensions)
      width = dimensions.delete(:width) || width
      height = dimensions.delete(:height) || height
      reject_unknown_options!(dimensions)
      grid(
        u_segments: width_segments, v_segments: height_segments,
        point: ->(u, v) { [(u - 0.5) * width, (0.5 - v) * height, 0.0] },
        normal: ->(_u, _v) { [0.0, 0.0, 1.0] }
      )
    end

    def sphere(radius = 1.0, width_segments: 32, height_segments: 16, **dimensions)
      radius = dimensions.delete(:radius) || radius
      reject_unknown_options!(dimensions)
      radius = Float(radius)
      grid(
        u_segments: [Integer(width_segments), 3].max,
        v_segments: [Integer(height_segments), 2].max,
        point: lambda { |u, v|
          phi = u * Math::PI * 2.0
          theta = v * Math::PI
          [-(radius * Math.cos(phi) * Math.sin(theta)), radius * Math.cos(theta),
           radius * Math.sin(phi) * Math.sin(theta)]
        },
        normal: lambda { |u, v|
          phi = u * Math::PI * 2.0
          theta = v * Math::PI
          [-Math.cos(phi) * Math.sin(theta), Math.cos(theta), Math.sin(phi) * Math.sin(theta)]
        }
      )
    end

    def cylinder(radius_top = 1.0, radius_bottom = 1.0, height = 1.0,
                 radial_segments: 32, height_segments: 1, open_ended: false, **dimensions)
      radius_top = dimensions.delete(:radius_top) || radius_top
      radius_bottom = dimensions.delete(:radius_bottom) || radius_bottom
      height = dimensions.delete(:height) || height
      reject_unknown_options!(dimensions)
      radial = [Integer(radial_segments), 3].max
      vertical = [Integer(height_segments), 1].max
      slope = (radius_bottom - radius_top) / height.to_f
      side = grid(
        u_segments: radial,
        v_segments: vertical,
        point: lambda { |u, v|
          theta = u * Math::PI * 2.0
          radius = radius_top + ((radius_bottom - radius_top) * v)
          [radius * Math.sin(theta), (0.5 - v) * height, radius * Math.cos(theta)]
        },
        normal: lambda { |u, _v|
          theta = u * Math::PI * 2.0
          Larb::Vec3.new(Math.sin(theta), slope, Math.cos(theta)).normalize.to_a
        }
      )
      return side if open_ended

      caps = []
      caps << disc(radius_top, height / 2.0, radial, up: true) unless radius_top.to_f.zero?
      caps << disc(radius_bottom, -height / 2.0, radial, up: false) unless radius_bottom.to_f.zero?
      merge_geometries(side, *caps)
    end

    def torus(radius = 1.0, tube = 0.4, radial_segments: 12, tubular_segments: 48,
              arc: Math::PI * 2.0, **dimensions)
      radius = dimensions.delete(:radius) || radius
      tube = dimensions.delete(:tube) || tube
      reject_unknown_options!(dimensions)
      grid(
        u_segments: [Integer(tubular_segments), 3].max,
        v_segments: [Integer(radial_segments), 3].max,
        point: lambda { |u, v|
          angle = u * arc
          radial_angle = v * Math::PI * 2.0
          distance = radius + (tube * Math.cos(radial_angle))
          [distance * Math.cos(angle), distance * Math.sin(angle), tube * Math.sin(radial_angle)]
        },
        normal: lambda { |u, v|
          angle = u * arc
          radial_angle = v * Math::PI * 2.0
          [Math.cos(angle) * Math.cos(radial_angle), Math.sin(angle) * Math.cos(radial_angle),
           Math.sin(radial_angle)]
        }
      )
    end

    def grid(u_segments:, v_segments:, point:, normal:)
      positions = []
      normals = []
      uvs = []
      indices = []
      (0..v_segments).each do |iy|
        v = iy.to_f / v_segments
        (0..u_segments).each do |ix|
          u = ix.to_f / u_segments
          positions.concat(point.call(u, v))
          normals.concat(normal.call(u, v))
          uvs.concat([u, 1.0 - v])
        end
      end
      stride = u_segments + 1
      v_segments.times do |iy|
        u_segments.times do |ix|
          a = (iy * stride) + ix
          b = a + stride
          indices.concat([a, b, a + 1, b, b + 1, a + 1])
        end
      end
      build(positions, normals, uvs, indices)
    end
    private_class_method :grid

    def disc(radius, y, segments, up:)
      positions = [0.0, y, 0.0]
      normals = [0.0, up ? 1.0 : -1.0, 0.0]
      uvs = [0.5, 0.5]
      (0..segments).each do |index|
        angle = index.to_f / segments * Math::PI * 2.0
        x = radius * Math.sin(angle)
        z = radius * Math.cos(angle)
        positions.concat([x, y, z])
        normals.concat([0.0, up ? 1.0 : -1.0, 0.0])
        uvs.concat([(x / radius + 1.0) / 2.0, (z / radius + 1.0) / 2.0])
      end
      indices = segments.times.flat_map do |index|
        up ? [0, index + 1, index + 2] : [0, index + 2, index + 1]
      end
      build(positions, normals, uvs, indices)
    end
    private_class_method :disc

    def build(positions, normals, uvs, indices)
      index_format = positions.length / 3 > 65_535 ? :uint32 : :uint16
      Geometry.new
              .set_attribute(:position, data: positions.pack("e*"), format: :float32x3, count: positions.length / 3)
              .set_attribute(:normal, data: normals.pack("e*"), format: :float32x3, count: normals.length / 3)
              .set_attribute(:uv, data: uvs.pack("e*"), format: :float32x2, count: uvs.length / 2)
              .set_index(data: indices.pack(index_format == :uint16 ? "S<*" : "L<*"), format: index_format)
    end
    private_class_method :build

    def merge_geometries(*geometries)
      positions = []
      normals = []
      uvs = []
      indices = []
      vertex_offset = 0
      geometries.each do |geometry|
        positions.concat(geometry.attribute(:position).data.unpack("e*"))
        normals.concat(geometry.attribute(:normal).data.unpack("e*"))
        uvs.concat(geometry.attribute(:uv).data.unpack("e*"))
        directive = geometry.index.format == :uint16 ? "S<*" : "L<*"
        indices.concat(geometry.index.data.unpack(directive).map { |index| index + vertex_offset })
        vertex_offset += geometry.attribute(:position).count
      end
      build(positions, normals, uvs, indices)
    end
    private_class_method :merge_geometries

    def reject_unknown_options!(options)
      return if options.empty?

      raise ArgumentError, "unknown geometry options: #{options.keys.join(", ")}"
    end
    private_class_method :reject_unknown_options!
  end
end
