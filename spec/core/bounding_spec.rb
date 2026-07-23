# frozen_string_literal: true

RSpec.describe Stagecraft::Bounding::Frustum do
  let(:camera) do
    Stagecraft::Cameras::Perspective.new(fov: 60, aspect: 1.0, near: 0.1, far: 10.0)
  end

  subject(:frustum) { described_class.from_matrix(camera.view_projection_matrix) }

  it "accepts spheres inside WebGPU zero-to-one clip space" do
    sphere = Stagecraft::Bounding::Sphere.new(Larb::Vec3.new(0, 0, -2), 0.5)

    expect(frustum).to be_intersects_sphere(sphere)
  end

  it "rejects spheres behind and beyond the camera" do
    behind = Stagecraft::Bounding::Sphere.new(Larb::Vec3.new(0, 0, 2), 0.1)
    distant = Stagecraft::Bounding::Sphere.new(Larb::Vec3.new(0, 0, -20), 0.1)

    expect(frustum).not_to be_intersects_sphere(behind)
    expect(frustum).not_to be_intersects_sphere(distant)
  end
end
