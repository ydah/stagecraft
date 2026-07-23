# frozen_string_literal: true

RSpec.describe Stagecraft::Geometry do
  let(:positions) do
    [
      0.0, 0.0, 0.0,
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0
    ].pack("e*")
  end

  subject(:geometry) do
    described_class.new
                   .set_attribute(:position, data: positions, format: :float32x3, count: 3)
                   .set_index(data: [0, 1, 2].pack("S<*"), format: :uint16)
  end

  it "computes bounds lazily" do
    expect(geometry.bounding_box.min.to_a).to eq([0.0, 0.0, 0.0])
    expect(geometry.bounding_box.max.to_a).to eq([1.0, 1.0, 0.0])
    expect(geometry.bounding_sphere.center.to_a).to eq([0.5, 0.5, 0.0])
    expect(geometry.bounding_sphere.radius).to be_within(1e-6).of(Math.sqrt(0.5))
  end

  it "computes averaged indexed normals" do
    geometry.compute_normals!

    values = geometry.attribute(:normal).data.unpack("e*")
    expect(values.each_slice(3).to_a).to all(eq([0.0, 0.0, 1.0]))
  end

  it "invalidates the geometry when attribute storage changes" do
    version = geometry.version

    geometry.attribute(:position).data = positions

    expect(geometry.version).to eq(version + 1)
  end

  it "notifies explicit disposal once" do
    disposed = []
    geometry.on_dispose { |resource| disposed << resource }

    geometry.dispose.dispose

    expect(disposed).to eq([geometry])
    expect { geometry.set_index(data: "".b, format: :uint16) }
      .to raise_error(Stagecraft::DisposedError)
  end
end
