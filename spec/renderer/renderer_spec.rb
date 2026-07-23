# frozen_string_literal: true

RSpec.describe Stagecraft::Renderer do
  it "records sorted draw commands without a GPU" do
    backend = SpecSupport::RecordingBackend.new
    renderer = described_class.new(width: 32, height: 32, backend:)
    scene = Stagecraft::Scene.new
    mesh = Stagecraft::Mesh.new(
      Stagecraft::Geometries.box,
      Stagecraft::Materials::Unlit.new(color: "#ff0000")
    )
    scene.add(mesh)
    camera = Stagecraft::Cameras::Perspective.new(aspect: 1.0)
    camera.position.z = 3

    renderer.render(scene, camera)

    draw = backend.commands.find { |command| command.first == :draw }
    expect(draw.dig(1, :mesh)).to equal(mesh)
    expect(draw.dig(1, :features)).to include(:HAS_UV)
    expect(renderer.stats.draw_calls).to eq(1)
    expect(renderer.stats.triangles).to eq(12)
  end

  it "rejects use after disposal" do
    renderer = described_class.new(backend: SpecSupport::RecordingBackend.new)
    renderer.dispose

    expect { renderer.render(Stagecraft::Scene.new, Stagecraft::Cameras::Perspective.new) }
      .to raise_error(Stagecraft::DisposedError)
  end
end
