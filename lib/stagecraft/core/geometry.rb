# frozen_string_literal: true

module Stagecraft
  class Geometry
    ATTRIBUTE_NAMES = %i[position normal uv uv1 tangent color joints weights].freeze

    TOPOLOGIES = %i[point_list line_list line_strip triangle_list triangle_strip].freeze

    attr_reader :index, :version, :topology

    def initialize(topology: :triangle_list)
      @attributes = {}
      @index = nil
      @version = 0
      @disposed = false
      @dispose_callbacks = []
      @bounding_version = -1
      self.topology = topology
    end

    def set_attribute(name, data:, format:, count:)
      ensure_alive!
      key = name.to_sym
      raise ArgumentError, "unsupported attribute #{name.inspect}" unless ATTRIBUTE_NAMES.include?(key)

      @attributes[key] = Attribute.new(data:, format:, count:) { changed! }
      changed!
      self
    end

    def delete_attribute(name)
      return nil unless @attributes.delete(name.to_sym)

      changed!
    end

    def attribute(name)
      @attributes[name.to_sym]
    end

    def attributes
      @attributes.dup.freeze
    end

    def set_index(data:, format:)
      ensure_alive!
      @index = IndexAttribute.new(data:, format:) { changed! }
      changed!
      self
    end

    def topology=(value)
      next_value = value.to_sym
      raise ArgumentError, "unsupported topology #{value.inspect}" unless TOPOLOGIES.include?(next_value)
      return next_value if @topology == next_value

      @topology = next_value
      changed!
      next_value
    end

    def bounding_box
      refresh_bounds! if @bounding_version != version
      @bounding_box
    end

    def bounding_sphere
      refresh_bounds! if @bounding_version != version
      @bounding_sphere
    end

    def compute_normals!
      positions = position_values
      normals = Array.new(positions.length) { Larb::Vec3.new }
      triangle_indices.each_slice(3) do |a, b, c|
        break unless c

        face = (positions[b] - positions[a]).cross(positions[c] - positions[a])
        normals[a] = normals[a] + face
        normals[b] = normals[b] + face
        normals[c] = normals[c] + face
      end
      packed = normals.flat_map { |normal| normal.length.zero? ? [0.0, 1.0, 0.0] : normal.normalize.to_a }.pack("e*")
      set_attribute(:normal, data: packed, format: :float32x3, count: positions.length)
    end

    def on_dispose(&block)
      @dispose_callbacks << block
      self
    end

    def dispose
      return self if @disposed

      @disposed = true
      @version += 1
      @dispose_callbacks.each { |callback| callback.call(self) }
      @dispose_callbacks.clear
      self
    end

    def disposed?
      @disposed
    end

    private

    def ensure_alive!
      raise DisposedError, "geometry has been disposed" if disposed?
    end

    def changed!
      @version += 1
      @bounding_version = -1
      self
    end

    def position_values
      position = attribute(:position)
      raise Error, "geometry has no position attribute" unless position
      raise Error, "bounding and normals require :float32x3 positions" unless position.format == :float32x3

      position.data.unpack("e*").each_slice(3).map { |values| Larb::Vec3.new(*values) }
    end

    def triangle_indices
      values = if index
                 index.data.unpack(index.format == :uint16 ? "S<*" : "L<*")
               else
                 (0...position_values.length).to_a
               end
      return values if topology == :triangle_list
      unless topology == :triangle_strip
        raise Error, "normal computation requires triangle geometry, got #{topology}"
      end
      return [] if values.length < 3

      (0..(values.length - 3)).flat_map do |offset|
        a, b, c = values.slice(offset, 3)
        offset.odd? ? [b, a, c] : [a, b, c]
      end
    end

    def refresh_bounds!
      positions = position_values
      box = Bounding::Box3.new
      positions.each { |point| box.expand_by_point(point) }
      center = box.center
      radius = positions.map { |point| point.distance(center) }.max || 0.0
      @bounding_box = box
      @bounding_sphere = Bounding::Sphere.new(center, radius)
      @bounding_version = version
    end
  end
end
