# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer::PipelineFactory do
  subject(:factory) { described_class.allocate }

  it "includes PBR texture slots in the bind-group invalidation signature" do
    texture = Stagecraft::Texture.new
    material = Stagecraft::Materials::PBR.new(base_color_map: texture)
    first = factory.send(:material_texture_versions, material)

    material.base_color_map = nil
    material.emissive_map = texture
    second = factory.send(:material_texture_versions, material)

    expect(first).not_to eq(second)
    expect(first.assoc(:base_color_map)).to eq([:base_color_map, texture.object_id, texture.version])
    expect(second.assoc(:emissive_map)).to eq([:emissive_map, texture.object_id, texture.version])
  end

  it "detects in-place changes to custom shader uniform values" do
    direction = Larb::Vec3.new(1, 0, 0)
    material = Stagecraft::Materials::Shader.new(
      wgsl: "",
      uniforms: { direction: }
    )
    first = factory.send(:material_value_signature, material)

    direction.x = 2
    second = factory.send(:material_value_signature, material)

    expect(second).not_to eq(first)
  end
end
