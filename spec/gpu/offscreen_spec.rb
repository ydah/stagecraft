# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer, :gpu do
  it "renders an offscreen image through the WebGPU frame graph" do
    scene = Stagecraft::Scene.new
    scene.add(Stagecraft::Lights::Ambient.new(intensity: 1.0))
    scene.add(
      Stagecraft::Mesh.new(
        Stagecraft::Geometries.box,
        Stagecraft::Materials::PBR.new(base_color: "#00ff00", metallic: 0.0)
      )
    )
    camera = Stagecraft::Cameras::Perspective.new(aspect: 1.0, near: 0.1, far: 10)
    camera.position.z = 3
    renderer = described_class.offscreen(width: 16, height: 16, msaa: 1)

    image = renderer.render(scene, camera).read_pixels
    pixel = image.data.byteslice(((8 * 16) + 8) * 4, 4).bytes

    expect(pixel[1]).to be > 100
    expect(pixel.values_at(0, 2)).to all(be < 30)
  rescue WGPU::AdapterError => error
    raise if ENV["STAGECRAFT_GPU_REQUIRED"] == "1"

    skip "WebGPU adapter unavailable: #{error.message.lines.first.strip}"
  ensure
    renderer&.dispose
  end

  it "multiplies unlit materials by vertex colors" do
    geometry = Stagecraft::Geometries.box
    geometry.set_attribute(
      :color,
      data: ([0, 255, 0, 255] * 24).pack("C*"),
      format: :unorm8x4,
      count: 24
    )
    scene = Stagecraft::Scene.new
    scene.add(
      Stagecraft::Mesh.new(
        geometry,
        Stagecraft::Materials::Unlit.new(color: "#ffffff")
      )
    )
    camera = Stagecraft::Cameras::Perspective.new(aspect: 1.0, near: 0.1, far: 10)
    camera.position.z = 3
    renderer = described_class.offscreen(width: 16, height: 16, msaa: 1)

    image = renderer.render(scene, camera).read_pixels
    pixel = image.data.byteslice(((8 * 16) + 8) * 4, 4).bytes

    expect(pixel[1]).to be > 100
    expect(pixel.values_at(0, 2)).to all(be < 30)
  rescue WGPU::AdapterError => error
    raise if ENV["STAGECRAFT_GPU_REQUIRED"] == "1"

    skip "WebGPU adapter unavailable: #{error.message.lines.first.strip}"
  ensure
    renderer&.dispose
  end
end
