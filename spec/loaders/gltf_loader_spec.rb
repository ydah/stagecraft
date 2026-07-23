# frozen_string_literal: true

require "spec_helper"
require "rgltf"

RSpec.describe Stagecraft::Loaders::GLTF do
  it "converts topology, materials, cameras, lights, and animation channels" do
    document = Rgltf.load_json(gltf_json, buffers: gltf_buffer)

    result = described_class.load(document)
    animated = result.scene.find("animated")
    mesh = animated.children.find { |child| child.is_a?(Stagecraft::Mesh) }
    attachment = animated.children.find { |child| child.name == "attachment" }

    expect(mesh.material).to be_a(Stagecraft::Materials::Unlit)
    expect(mesh.geometry.topology).to eq(:line_list)
    expect(mesh.geometry.index.format).to eq(:uint32)
    expect(mesh.geometry.index.count).to eq(6)
    expect(attachment.children).to include(
      an_instance_of(Stagecraft::Cameras::Perspective),
      an_instance_of(Stagecraft::Lights::Point)
    )
    expect(result.cameras).to contain_exactly(an_instance_of(Stagecraft::Cameras::Perspective))
    expect(result.animations.first.name).to eq("move")

    mixer = Stagecraft::Animation::Mixer.new(result.scene)
    mixer.play(result.animations.first, loop: :once)
    mixer.update(0.5)
    expect(animated.position.to_a).to eq([1.0, 0.0, 0.0])
  end

  def gltf_buffer
    @gltf_buffer ||= begin
      positions = [0, 0, 0, 1, 0, 0, 0, 1, 0].pack("e*")
      indices = [0, 1, 2].pack("C*")
      times = [0.0, 1.0].pack("e*")
      translations = [0, 0, 0, 2, 0, 0].pack("e*")
      positions + indices + "\0" + times + translations
    end
  end

  def gltf_json
    {
      "asset" => { "version" => "2.0" },
      "extensionsUsed" => %w[KHR_materials_unlit KHR_lights_punctual],
      "extensions" => {
        "KHR_lights_punctual" => {
          "lights" => [{ "name" => "lamp", "type" => "point", "intensity" => 2.0 }]
        }
      },
      "buffers" => [{ "byteLength" => gltf_buffer.bytesize }],
      "bufferViews" => [
        { "buffer" => 0, "byteOffset" => 0, "byteLength" => 36 },
        { "buffer" => 0, "byteOffset" => 36, "byteLength" => 3 },
        { "buffer" => 0, "byteOffset" => 40, "byteLength" => 8 },
        { "buffer" => 0, "byteOffset" => 48, "byteLength" => 24 }
      ],
      "accessors" => [
        { "bufferView" => 0, "componentType" => 5_126, "count" => 3, "type" => "VEC3" },
        { "bufferView" => 1, "componentType" => 5_121, "count" => 3, "type" => "SCALAR" },
        {
          "bufferView" => 2, "componentType" => 5_126, "count" => 2, "type" => "SCALAR",
          "min" => [0.0], "max" => [1.0]
        },
        { "bufferView" => 3, "componentType" => 5_126, "count" => 2, "type" => "VEC3" }
      ],
      "materials" => [
        {
          "name" => "flat",
          "pbrMetallicRoughness" => { "baseColorFactor" => [0.2, 0.4, 0.8, 1.0] },
          "extensions" => { "KHR_materials_unlit" => {} }
        }
      ],
      "meshes" => [
        {
          "name" => "loop",
          "primitives" => [
            { "attributes" => { "POSITION" => 0 }, "indices" => 1, "material" => 0, "mode" => 2 }
          ]
        }
      ],
      "cameras" => [
        { "name" => "view", "type" => "perspective", "perspective" => { "yfov" => 1.0, "znear" => 0.1 } }
      ],
      "nodes" => [
        { "name" => "animated", "mesh" => 0, "children" => [1] },
        {
          "name" => "attachment",
          "camera" => 0,
          "extensions" => { "KHR_lights_punctual" => { "light" => 0 } }
        }
      ],
      "scenes" => [{ "nodes" => [0] }],
      "scene" => 0,
      "animations" => [
        {
          "name" => "move",
          "samplers" => [{ "input" => 2, "output" => 3 }],
          "channels" => [{ "sampler" => 0, "target" => { "node" => 0, "path" => "translation" } }]
        }
      ]
    }
  end
end
