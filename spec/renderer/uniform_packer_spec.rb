# frozen_string_literal: true

RSpec.describe Stagecraft::Renderer::UniformPacker do
  subject(:packer) { described_class.new }

  it "applies WGSL alignment including vec3 padding" do
    result = packer.pack(
      scalar: 1.0,
      direction: Larb::Vec3.new(1, 2, 3),
      amount: 2.0
    )

    expect(result.fields.map { |field| [field.name, field.offset] })
      .to eq([[:scalar, 0], [:direction, 16], [:amount, 28]])
    expect(result.bytes.bytesize).to eq(32)
    expect(result.struct_source).to include("direction: vec3f")
  end

  it "separates textures from packed uniform values" do
    texture = Stagecraft::Texture.new
    result = packer.pack(color: Stagecraft::Color.new(1, 0, 0), map: texture)

    expect(result.textures).to eq([[:map, texture]])
    expect(result.fields.map(&:name)).to eq([:color])
  end
end
