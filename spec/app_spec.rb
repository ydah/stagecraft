# frozen_string_literal: true

RSpec.describe Stagecraft::App do
  FakeWindow = Struct.new(:closed, :poll_count) do
    def drawable_size
      [640, 320]
    end

    def poll_events
      self.poll_count += 1
    end

    def should_close?
      poll_count > 1
    end

    def close
      self.closed = true
    end
  end

  FakeRenderer = Struct.new(:disposed) do
    def dispose
      self.disposed = true
    end
  end

  it "clamps delta time and disposes owned loop resources" do
    window = FakeWindow.new(false, 0)
    renderer = FakeRenderer.new(false)
    app = described_class.new(window:, renderer:)
    deltas = []

    app.run { |dt| deltas << dt }

    expect(app.aspect).to eq(2.0)
    expect(deltas).to all(be_between(0.0, 0.1))
    expect(window.closed).to be(true)
    expect(renderer.disposed).to be(true)
  end
end
