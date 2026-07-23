# frozen_string_literal: true

RSpec.describe Stagecraft::Node do
  it "maintains hierarchy and traverses depth first" do
    root = described_class.new(name: "root")
    first = described_class.new(name: "first")
    grandchild = described_class.new(name: "grandchild")
    second = described_class.new(name: "second")

    root.add(first.add(grandchild), second)

    expect(root.traverse.map(&:name)).to eq(%w[root first grandchild second])
    expect(root.find("grandchild")).to equal(grandchild)
    expect(first.parent).to equal(root)
  end

  it "detaches nodes from an existing parent" do
    first_parent = described_class.new
    second_parent = described_class.new
    child = described_class.new

    first_parent.add(child)
    second_parent.add(child)

    expect(first_parent.children).to be_empty
    expect(second_parent.children).to contain_exactly(child)
  end

  it "rejects hierarchy cycles" do
    parent = described_class.new
    child = described_class.new
    parent.add(child)

    expect { child.add(parent) }.to raise_error(ArgumentError, /cycle/)
  end

  it "lazily updates world transforms using version stamps" do
    root = described_class.new
    child = described_class.new
    root.add(child)
    child.position.set(1, 0, 0)

    expect(child.world_position.to_a).to eq([1.0, 0.0, 0.0])
    initial_version = child.world_version

    expect(child.world_position.to_a).to eq([1.0, 0.0, 0.0])
    expect(child.world_version).to eq(initial_version)

    root.position.x = 2
    expect(child.world_version).to eq(initial_version)
    expect(child.world_position.to_a).to eq([3.0, 0.0, 0.0])
    expect(child.world_version).to eq(initial_version + 1)
  end

  it "observes quaternion mutations" do
    node = described_class.new
    original = node.world_matrix

    node.rotation.rotate_y!(Math::PI / 2.0)

    expect(node.world_matrix).not_to eq(original)
  end
end
