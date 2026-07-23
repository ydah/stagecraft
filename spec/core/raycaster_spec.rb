# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Raycaster do
  it "starts perspective camera rays at the camera world position" do
    rig = Stagecraft::Node.new
    camera = Stagecraft::Cameras::Perspective.new(
      fov: 60,
      aspect: 1.0,
      near: 1.0,
      far: 10.0
    )
    rig.position.x = 2.0
    camera.position.z = 5.0
    rig.add(camera)

    ray = described_class.new.set_from_camera(0.0, 0.0, camera)

    expect(ray.origin.to_a).to eq([2.0, 0.0, 5.0])
    expect(ray.direction.to_a.values_at(0, 1)).to all(be_within(1.0e-6).of(0.0))
    expect(ray.direction.z).to be_within(1.0e-6).of(-1.0)
  end

  it "validates its clipping interval" do
    expect { described_class.new(near: -1.0) }.to raise_error(ArgumentError, /near/)
    expect { described_class.new(near: 2.0, far: 1.0) }.to raise_error(ArgumentError, /far/)
  end
end
