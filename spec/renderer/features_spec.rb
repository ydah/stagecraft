# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer::Features do
  it "selects a vec3 vertex-color shader for float RGB attributes" do
    geometry = Stagecraft::Geometry.new
    geometry.set_attribute(
      :position,
      data: [0, 0, 0, 1, 0, 0, 0, 1, 0].pack("e*"),
      format: :float32x3,
      count: 3
    )
    geometry.set_attribute(
      :color,
      data: [1, 0, 0, 0, 1, 0, 0, 0, 1].pack("e*"),
      format: :float32x3,
      count: 3
    )
    geometry.set_attribute(
      :uv1,
      data: [0, 0, 1, 0, 0, 1].pack("e*"),
      format: :float32x2,
      count: 3
    )
    mesh = Stagecraft::Mesh.new(geometry, Stagecraft::Materials::PBR.new)
    features = described_class.for(mesh)

    source = Stagecraft::Renderer::Shaders.compose("pbr.wgsl", defines: features)
    unlit = Stagecraft::Renderer::Shaders.compose("unlit.wgsl", defines: features)

    expect(features).to include(:HAS_VERTEX_COLOR, :COLOR_VEC3, :HAS_UV1)
    expect(source).to include("@location(4) color: vec3f")
    expect(source).to include("output.color = vec4f(input.color, 1.0)")
    expect(source).to include("@location(7) uv1: vec2f")
    expect(unlit).to include("@location(4) color: vec3f")
    expect(unlit).to include("material.color * input.color")
  end

  it "reconstructs a tangent frame for normal maps without tangent attributes" do
    geometry = Stagecraft::Geometries.plane
    material = Stagecraft::Materials::PBR.new(normal_map: Stagecraft::Texture.new)
    mesh = Stagecraft::Mesh.new(geometry, material)

    source = Stagecraft::Renderer::Shaders.compose(
      "pbr.wgsl",
      defines: described_class.for(mesh)
    )

    expect(source).to include("fn cotangent_frame")
    expect(source).to include(
      "normal = normalize(cotangent_frame(normal, input.world_position, uv) * mapped);"
    )
    expect(source).not_to include("@location(3) tangent: vec4f")
  end
end
