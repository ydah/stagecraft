# frozen_string_literal: true

RSpec.describe Stagecraft::Renderer::PipelineCache do
  Resource = Struct.new(:released) do
    def release
      self.released = true
    end
  end

  it "uses LRU eviction and releases evicted pipelines" do
    cache = described_class.new(limit: 2)
    first = cache.fetch(:first) { Resource.new(false) }
    second = cache.fetch(:second) { Resource.new(false) }
    cache.fetch(:first) { raise "cache miss" }

    cache.fetch(:third) { Resource.new(false) }

    expect(first.released).to be(false)
    expect(second.released).to be(true)
    expect(cache.size).to eq(2)
  end
end
