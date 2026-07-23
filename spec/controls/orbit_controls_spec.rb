# frozen_string_literal: true

RSpec.describe Stagecraft::Controls::Orbit do
  let(:camera) do
    Stagecraft::Cameras::Perspective.new.tap { |value| value.position.set(0, 0, 5) }
  end

  it "orbits and zooms while keeping the camera aimed at the target" do
    controls = described_class.new(camera)
    controls.rotate(100, 20).zoom(-1).update(1.0)

    expect(camera.world_position).not_to eq(Larb::Vec3.new(0, 0, 5))
    forward = camera.rotation.to_larb * Larb::Vec3.forward
    expected = (controls.target - camera.world_position).normalize
    expect(forward.near?(expected, 1e-5)).to be(true)
  end
end
