# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stagecraft::Textures::SamplerState do
  it "normalizes glTF wrap names" do
    sampler = described_class.new(wrap_u: :mirrored_repeat, wrap_v: :clamp_to_edge)

    expect(sampler.wrap_u).to eq(:mirror_repeat)
    expect(sampler.wrap_v).to eq(:clamp_to_edge)
  end

  it "rejects invalid LOD and anisotropy combinations" do
    expect { described_class.new(lod_min: 2, lod_max: 1) }
      .to raise_error(ArgumentError, /lod_max/)
    expect { described_class.new(max_anisotropy: 2, min_filter: :nearest) }
      .to raise_error(ArgumentError, /linear filters/)
    expect { described_class.new(max_anisotropy: 17) }
      .to raise_error(ArgumentError, /between 1 and 16/)
  end
end
