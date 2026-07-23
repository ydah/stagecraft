# frozen_string_literal: true

RSpec.describe Stagecraft::Renderer::RenderList do
  let(:geometry) { Stagecraft::Geometries.box }
  let(:camera) do
    Stagecraft::Cameras::Perspective.new(fov: 60, aspect: 1.0, near: 0.1, far: 100).tap do |value|
      value.position.z = 5
    end
  end

  it "culls meshes outside the camera frustum" do
    scene = Stagecraft::Scene.new
    visible = Stagecraft::Mesh.new(geometry, Stagecraft::Materials::PBR.new)
    hidden = Stagecraft::Mesh.new(geometry, Stagecraft::Materials::PBR.new)
    hidden.position.x = 1_000
    scene.add(visible, hidden)

    list = described_class.new(scene, camera)

    expect(list.items.map(&:mesh)).to eq([visible])
    expect(list.culled_count).to eq(1)
  end

  it "sorts opaque front-to-back and transparent back-to-front" do
    scene = Stagecraft::Scene.new
    opaque_material = Stagecraft::Materials::PBR.new
    blend_material = Stagecraft::Materials::PBR.new(alpha_mode: :blend)
    near_opaque = Stagecraft::Mesh.new(geometry, opaque_material)
    far_opaque = Stagecraft::Mesh.new(geometry, opaque_material)
    far_opaque.position.z = -5
    near_blend = Stagecraft::Mesh.new(geometry, blend_material)
    far_blend = Stagecraft::Mesh.new(geometry, blend_material)
    far_blend.position.z = -5
    scene.add(far_opaque, near_opaque, near_blend, far_blend)

    list = described_class.new(scene, camera)

    expect(list.opaque.map(&:mesh)).to eq([near_opaque, far_opaque])
    expect(list.transparent.map(&:mesh)).to eq([far_blend, near_blend])
  end

  it "accumulates ambient light separately" do
    scene = Stagecraft::Scene.new
    scene.add(Stagecraft::Lights::Ambient.new(color: [0.5, 0.25, 0.0], intensity: 2.0))

    expect(described_class.new(scene, camera).ambient.to_a).to eq([1.0, 0.5, 0.0])
  end
end
