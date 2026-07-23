# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Skin do
  it "builds joint matrices in mesh-local space" do
    mesh = Stagecraft::Mesh.new(
      Stagecraft::Geometries.plane,
      Stagecraft::Materials::Unlit.new
    )
    mesh.position.set(2.0, 0.0, 0.0)
    joint = Stagecraft::Node.new
    joint.position.set(5.0, 0.0, 0.0)
    inverse_bind = Larb::Mat4.translation(-1.0, 0.0, 0.0)
    skin = described_class.new(joints: [joint], inverse_bind_matrices: [inverse_bind])

    expected = inverse_bind * joint.world_matrix * mesh.world_matrix.inverse
    expect(skin.joint_matrices(mesh).first).to be_near(expected)
  end
end
