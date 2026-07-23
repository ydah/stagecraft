# frozen_string_literal: true

require "spec_helper"
require "texel/wgpu"

RSpec.describe Stagecraft::Renderer::ResourceCache do
  class FakeGPUResource
    attr_reader :destroyed, :released

    def initialize
      @destroyed = false
      @released = false
    end

    def destroy
      @destroyed = true
    end

    def release
      @released = true
    end
  end

  class FakeGPUTexture < FakeGPUResource
    attr_reader :view

    def create_view
      @view = FakeGPUResource.new
    end
  end

  class FakeDevice
    attr_reader :buffers

    def initialize
      @buffers = []
    end

    def create_buffer_with_data(**)
      FakeGPUResource.new.tap { |buffer| buffers << buffer }
    end

    def create_sampler(**)
      FakeGPUResource.new
    end
  end

  let(:device) { FakeDevice.new }
  let(:stats) { Stagecraft::Renderer::Stats.new }
  let(:cache) { described_class.new(device:, queue: Object.new, stats:) }

  it "replaces versioned buffers and destroys them after the in-flight delay" do
    geometry = Stagecraft::Geometries.box
    first = cache.gpu_geometry(geometry)
    geometry.attribute(:position).data = geometry.attribute(:position).data
    second = cache.gpu_geometry(geometry)

    expect(second).not_to equal(first)
    expect(cache.live_count).to eq(1)

    3.times { cache.advance_frame }
    expect(first.vertex_buffers.values).to all(have_attributes(destroyed: true, released: true))
    expect(second.vertex_buffers.values).to all(have_attributes(destroyed: false))

    geometry.dispose
    3.times { cache.advance_frame }
    expect(second.vertex_buffers.values).to all(have_attributes(destroyed: true, released: true))
    expect(cache.live_count).to eq(0)
  end

  it "applies the Texture color space at the upload boundary" do
    image = Texel::Image.new(
      width: 1, height: 1, channels: 4, dtype: :u8, color_space: :linear,
      data: [255, 255, 255, 255].pack("C*")
    )
    texture = Stagecraft::Texture.new(image, color_space: :srgb)
    uploaded_image = nil
    allow(Texel::WGPU).to receive(:upload) do |next_image, **|
      uploaded_image = next_image
      FakeGPUTexture.new
    end

    cache.gpu_texture(texture)

    expect(uploaded_image.color_space).to eq(:srgb)
  ensure
    cache.dispose_all
  end
end
