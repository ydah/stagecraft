# frozen_string_literal: true

RSpec.describe Stagecraft::Renderer::Shaders do
  it "composes includes and enabled feature branches" do
    source = described_class.compose("unlit.wgsl", defines: Set[:HAS_UV, :ALPHA_MASK])

    expect(source).to include("struct FrameUniforms")
    expect(source).to include("@location(2) uv: vec2f")
    expect(source).to include("discard")
    expect(source).not_to include("//#include")
    expect(source).not_to include("//#if")
  end

  it "removes disabled feature branches" do
    source = described_class.compose("unlit.wgsl")

    expect(source).not_to include("@location(2) uv: vec2f")
    expect(source).not_to include("discard")
    expect(source).to include("output.uv = vec2f(0.0)")
  end
end
