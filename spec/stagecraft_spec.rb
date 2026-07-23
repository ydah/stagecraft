# frozen_string_literal: true

RSpec.describe Stagecraft do
  it "exposes a version" do
    expect(Stagecraft::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "parses hexadecimal colors" do
    color = Stagecraft::Color.new("#e91e63")

    expect(color.to_a).to match([
      be_within(1e-6).of(233.0 / 255.0),
      be_within(1e-6).of(30.0 / 255.0),
      be_within(1e-6).of(99.0 / 255.0),
      1.0
    ])
  end
end
