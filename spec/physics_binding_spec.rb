# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::PhysicsBinding do
  Body = Struct.new(:position, :rotation)

  it "interpolates from snapshots of mutable body transforms" do
    node = Stagecraft::Node.new
    body = Body.new(
      Larb::Vec3.new,
      Larb::Quat.identity
    )
    binding = described_class.new.bind(node, body)

    body.position.x = 10.0
    target_rotation = Larb::Quat.from_axis_angle(Larb::Vec3.up, Math::PI)
    body.rotation.x = target_rotation.x
    body.rotation.y = target_rotation.y
    body.rotation.z = target_rotation.z
    body.rotation.w = target_rotation.w
    binding.sync!(0.5)

    expect(node.position.x).to be_within(1.0e-6).of(5.0)
    forward = node.rotation.to_larb * Larb::Vec3.forward
    expect(forward.x.abs).to be_within(1.0e-6).of(1.0)
    expect(forward.z).to be_within(1.0e-6).of(0.0)
  end

  it "replaces an existing binding for the same node" do
    node = Stagecraft::Node.new
    first = Body.new(Larb::Vec3.new, Larb::Quat.identity)
    second = Body.new(Larb::Vec3.new(4, 0, 0), Larb::Quat.identity)
    binding = described_class.new.bind(node, first).bind(node, second)

    first.position.x = 100.0
    binding.sync!

    expect(node.position.x).to eq(4.0)
  end
end
