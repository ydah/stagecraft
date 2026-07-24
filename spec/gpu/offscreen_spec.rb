# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer, :gpu do
  it "initializes the native texture view usage field" do
    require "wgpu"

    described_class::WGPUCompatibility.install!
    descriptor = WGPU::Native::TextureViewDescriptor

    expect(descriptor.members.last).to eq(:usage)
    expect(descriptor.offset_of(:usage)).to eq(56)
    expect(descriptor.size).to eq(64)
    expect(descriptor.new[:usage]).to eq(0)
  end

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

  it "applies normal maps to geometry without tangent attributes" do
    require "texel"

    image = Texel::Image.new(
      width: 1,
      height: 1,
      channels: 4,
      dtype: :u8,
      color_space: :linear,
      data: [255, 128, 128, 255].pack("C*")
    )
    normal_map = Stagecraft::Texture.new(image, color_space: :linear)
    material = Stagecraft::Materials::PBR.new(
      base_color: "#ffffff",
      metallic: 0.0,
      roughness: 1.0,
      normal_map:
    )
    scene = Stagecraft::Scene.new
    scene.add(Stagecraft::Lights::Directional.new(intensity: 2.0))
    scene.add(Stagecraft::Mesh.new(Stagecraft::Geometries.plane, material))
    camera = Stagecraft::Cameras::Perspective.new(aspect: 1.0, near: 0.1, far: 10)
    camera.position.z = 3
    renderer = described_class.offscreen(width: 16, height: 16, msaa: 1)

    image = renderer.render(scene, camera).read_pixels
    pixel = image.data.byteslice(((8 * 16) + 8) * 4, 4).bytes

    expect(pixel.values_at(0, 1, 2)).to all(be < 30)
  rescue WGPU::AdapterError => error
    raise if ENV["STAGECRAFT_GPU_REQUIRED"] == "1"

    skip "WebGPU adapter unavailable: #{error.message.lines.first.strip}"
  ensure
    renderer&.dispose
  end
end
