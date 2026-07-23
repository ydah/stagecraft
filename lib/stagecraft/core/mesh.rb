# frozen_string_literal: true

module Stagecraft
  class Mesh < Node
    attr_reader :geometry, :material
    attr_accessor :frustum_culled, :skin, :morph_weights

    def initialize(geometry, material, **)
      super(**)
      self.geometry = geometry
      self.material = material
      @frustum_culled = true
      @morph_weights = []
    end

    def geometry=(value)
      raise ArgumentError, "expected a Stagecraft::Geometry" unless value.is_a?(Geometry)

      @geometry = value
    end

    def material=(value)
      @material = value
    end
  end
end
