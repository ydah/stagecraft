# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Renderer::GPUContext do
  it "releases an external surface when its configuration fails" do
    device = double("device", queue: Object.new)
    surface = double("surface")
    allow(surface).to receive(:capabilities).and_return(formats: [:rgba8_unorm_srgb])
    allow(surface).to receive(:configure).and_raise(Stagecraft::Error, "configure failed")
    expect(surface).to receive(:unconfigure)
    expect(surface).to receive(:release)

    expect do
      described_class.new(
        width: 16,
        height: 16,
        device:,
        surface:
      )
    end.to raise_error(Stagecraft::Error, "configure failed")
  end
end
