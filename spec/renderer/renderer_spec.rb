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

  it "attempts every cleanup when one resource fails to release" do
    renderer = described_class.new(backend: SpecSupport::RecordingBackend.new)
    pipelines = double("pipelines")
    resource_cache = double("resource cache", live_count: 0)
    resources = double("frame resources")
    context = double("GPU context")
    renderer.instance_variable_set(:@pipelines, pipelines)
    renderer.instance_variable_set(:@resource_cache, resource_cache)
    renderer.instance_variable_set(:@resources, resources)
    renderer.instance_variable_set(:@context, context)
    allow(renderer).to receive(:release_post_resources)
      .and_raise(Stagecraft::Error, "post release failed")
    expect(pipelines).to receive(:dispose)
    expect(resource_cache).to receive(:dispose_all)
    expect(resources).to receive(:dispose)
    expect(context).to receive(:dispose)

    expect { renderer.dispose }.to raise_error(Stagecraft::Error, "post release failed")
    expect(renderer).to be_disposed
  end

  it "releases an initialized GPU context when later setup fails" do
    context = double(
      "GPU context",
      device: Object.new,
      queue: Object.new,
      surface_format: :rgba8_unorm_srgb
    )
    allow(Stagecraft::Renderer::GPUContext).to receive(:new).and_return(context)
    allow(Stagecraft::Renderer::FrameResources).to receive(:new)
      .and_raise(Stagecraft::Error, "frame setup failed")
    expect(context).to receive(:dispose)

    expect { described_class.new(width: 16, height: 16) }
      .to raise_error(Stagecraft::Error, "frame setup failed")
  end
end
