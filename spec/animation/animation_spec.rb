# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Animation do
  it "samples vectors, quaternions, and cubic splines" do
    target = Stagecraft::Node.new
    translation = described_class::Track.new(
      times: [0.0, 1.0],
      values: [0.0, 0.0, 0.0, 2.0, 4.0, 6.0],
      target:,
      target_path: :translation
    )
    rotation = described_class::Track.new(
      times: [0.0, 1.0],
      values: [0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0],
      target:,
      target_path: :rotation
    )
    cubic = described_class::Track.new(
      times: [0.0, 1.0],
      values: [0.0, 0.0, 1.0, 1.0, 1.0, 0.0],
      target:,
      target_path: :weights,
      interpolation: :cubicspline,
      value_size: 1
    )

    expect(translation.sample(0.5)).to eq([1.0, 2.0, 3.0])
    midpoint = rotation.sample(0.5).map(&:abs)
    expect(midpoint.values_at(0, 2)).to eq([0.0, 0.0])
    expect(midpoint.values_at(1, 3)).to all(be_within(1.0e-6).of(Math.sqrt(0.5)))
    expect(cubic.sample(0.5)).to contain_exactly(be_within(1.0e-6).of(0.5))
  end

  it "blends actions and propagates morph weights to primitive meshes" do
    root = Stagecraft::Node.new
    target = Stagecraft::Node.new(name: "animated")
    mesh = Stagecraft::Mesh.new(
      Stagecraft::Geometries.plane,
      Stagecraft::Materials::Unlit.new
    )
    root.add(target)
    target.add(mesh)
    first = described_class::Clip.new(
      tracks: [
        described_class::Track.new(
          times: [0.0, 1.0], values: [0.0, 1.0],
          target: "animated", target_path: :weights, value_size: 1
        )
      ]
    )
    second = described_class::Clip.new(
      tracks: [
        described_class::Track.new(
          times: [0.0, 1.0], values: [0.0, 3.0],
          target: "animated", target_path: :weights, value_size: 1
        )
      ]
    )
    mixer = described_class::Mixer.new(root)
    mixer.play(first, loop: :once).weight = 1.0
    mixer.play(second, loop: :once).weight = 3.0

    mixer.update(0.5)

    expect(mesh.morph_weights).to contain_exactly(be_within(1.0e-6).of(1.25))
  end
end
