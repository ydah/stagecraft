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

  it "separates custom shader pipelines while reusing compatible layouts" do
    first = Stagecraft::Materials::Shader.new(
      wgsl: "fn first() {}",
      uniforms: { amount: 1.0 }
    )
    second = Stagecraft::Materials::Shader.new(
      wgsl: "fn second() {}",
      uniforms: { amount: 2.0 }
    )
    first_layout = factory.send(:material_layout_signature, first)
    second_layout = factory.send(:material_layout_signature, second)

    expect(first_layout).to eq(second_layout)
    expect(factory.send(:material_pipeline_signature, first, first_layout))
      .not_to eq(factory.send(:material_pipeline_signature, second, second_layout))
  end

  it "allows custom textures in vertex and fragment stages" do
    material = Stagecraft::Materials::Shader.new(
      wgsl: "",
      uniforms: { map: Stagecraft::Texture.new }
    )
    texture_entries = factory.send(:material_layout_entries, material).drop(1)

    expect(texture_entries).not_to be_empty
    expect(texture_entries).to all(include(visibility: %i[vertex fragment]))
  end
end
