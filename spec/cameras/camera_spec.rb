# frozen_string_literal: true

RSpec.describe Stagecraft::Cameras::Perspective do
  subject(:camera) { described_class.new(fov: 60, aspect: 16.0 / 9.0, near: 0.1, far: 100.0) }

  it "maps depth into WebGPU's zero-to-one NDC range" do
    near_clip = camera.projection_matrix * Larb::Vec4.new(0, 0, -camera.near, 1)
    far_clip = camera.projection_matrix * Larb::Vec4.new(0, 0, -camera.far, 1)

    expect(near_clip.z / near_clip.w).to be_within(1e-6).of(0.0)
    expect(far_clip.z / far_clip.w).to be_within(1e-6).of(1.0)
  end

  it "invalidates the projection cache when parameters change" do
    original = camera.projection_matrix
    camera.aspect = 1.0

    expect(camera.projection_matrix).not_to eq(original)
  end
end

RSpec.describe Stagecraft::Cameras::Orthographic do
  it "maps near and far depth into zero-to-one NDC" do
    camera = described_class.new(left: -2, right: 2, top: 1, bottom: -1, near: 1, far: 11)
    near_clip = camera.projection_matrix * Larb::Vec4.new(0, 0, -1, 1)
    far_clip = camera.projection_matrix * Larb::Vec4.new(0, 0, -11, 1)

    expect(near_clip.z).to be_within(1e-6).of(0.0)
    expect(far_clip.z).to be_within(1e-6).of(1.0)
  end
end
