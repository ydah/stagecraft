# frozen_string_literal: true

RSpec.describe Stagecraft::Geometries do
  {
    box: -> { described_class.box },
    sphere: -> { described_class.sphere(width_segments: 8, height_segments: 4) },
    plane: -> { described_class.plane(width_segments: 2, height_segments: 2) },
    cylinder: -> { described_class.cylinder(radial_segments: 8) },
    torus: -> { described_class.torus(radial_segments: 4, tubular_segments: 8) }
  }.each do |name, build|
    it "builds indexed #{name} geometry with position, normal, and uv attributes" do
      geometry = build.call

      expect(geometry.attribute(:position).count).to be_positive
      expect(geometry.attribute(:normal).count).to eq(geometry.attribute(:position).count)
      expect(geometry.attribute(:uv).count).to eq(geometry.attribute(:position).count)
      expect(geometry.index.count).to be_positive
    end
  end
end
