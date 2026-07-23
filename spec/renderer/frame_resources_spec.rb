# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer::FrameResources do
  it "destroys owned buffers and shadow textures during disposal" do
    stats = Stagecraft::Renderer::Stats.new
    stats.increment(:buffers, 4)
    buffers = Array.new(4) { double("GPU buffer", destroy: nil, release: nil) }
    shadow_texture = double("shadow texture", destroy: nil, release: nil)
    resources = described_class.allocate
    resources.instance_variable_set(:@stats, stats)
    resources.instance_variable_set(:@skin_bindings, {})
    resources.instance_variable_set(:@frame_buffer, buffers[0])
    resources.instance_variable_set(:@lights_buffer, buffers[1])
    resources.instance_variable_set(:@object_buffer, buffers[2])
    resources.instance_variable_set(:@joint_buffer, buffers[3])
    resources.instance_variable_set(:@shadow_texture, shadow_texture)
    buffers.each do |buffer|
      expect(buffer).to receive(:destroy)
      expect(buffer).to receive(:release)
    end
    expect(shadow_texture).to receive(:destroy)
    expect(shadow_texture).to receive(:release)

    resources.dispose

    expect(stats.buffers).to eq(0)
  end
end
