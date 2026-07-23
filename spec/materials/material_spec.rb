# frozen_string_literal: true

RSpec.describe Stagecraft::Materials::PBR do
  it "normalizes colors and versions parameter changes" do
    material = described_class.new(base_color: "#ffffff")
    version = material.version

    material.roughness = 0.25

    expect(material.base_color).to eq(Stagecraft::Color.new(1.0))
    expect(material.version).to eq(version + 1)
  end

  it "rejects invalid physical parameters" do
    expect { described_class.new(metallic: 2.0) }.to raise_error(ArgumentError, /metallic/)
    expect { described_class.new(roughness: -1.0) }.to raise_error(ArgumentError, /roughness/)
  end

  it "derives transparent queue membership" do
    expect(described_class.new(alpha_mode: :blend)).to be_transparent
    expect(described_class.new(opacity: 0.5)).to be_transparent
    expect(described_class.new).not_to be_transparent
  end
end
