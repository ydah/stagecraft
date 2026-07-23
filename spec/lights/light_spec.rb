# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Lights::Directional do
  it "derives its direction from the complete node hierarchy" do
    parent = Stagecraft::Node.new
    light = described_class.new
    parent.add(light)
    parent.rotation.rotate_y!(Math::PI / 2.0)

    expect(light.direction.x).to be_within(1.0e-6).of(-1.0)
    expect(light.direction.to_a.values_at(1, 2)).to all(be_within(1.0e-6).of(0.0))

    parent.rotation.rotate_y!(Math::PI / 2.0)

    expect(light.direction.z).to be_within(1.0e-6).of(1.0)
  end
end
