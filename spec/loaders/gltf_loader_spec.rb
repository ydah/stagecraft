# frozen_string_literal: true

require "spec_helper"
require "rgltf"
require "texel"

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

  it "converts skins and packed joint attributes" do
    positions = [0, 0, 0, 1, 0, 0, 0, 1, 0].pack("e*")
    joints = ([0, 0, 0, 0] * 3).pack("S<*")
    weights = ([1, 0, 0, 0] * 3).pack("e*")
    inverse_bind = Larb::Mat4.identity.to_a.pack("e*")
    buffer = positions + joints + weights + inverse_bind
    json = {
      "asset" => { "version" => "2.0" },
      "buffers" => [{ "byteLength" => buffer.bytesize }],
      "bufferViews" => [
        { "buffer" => 0, "byteOffset" => 0, "byteLength" => 36 },
        { "buffer" => 0, "byteOffset" => 36, "byteLength" => 24 },
        { "buffer" => 0, "byteOffset" => 60, "byteLength" => 48 },
        { "buffer" => 0, "byteOffset" => 108, "byteLength" => 64 }
      ],
      "accessors" => [
        { "bufferView" => 0, "componentType" => 5_126, "count" => 3, "type" => "VEC3" },
        { "bufferView" => 1, "componentType" => 5_123, "count" => 3, "type" => "VEC4" },
        { "bufferView" => 2, "componentType" => 5_126, "count" => 3, "type" => "VEC4" },
        { "bufferView" => 3, "componentType" => 5_126, "count" => 1, "type" => "MAT4" }
      ],
      "meshes" => [
        { "primitives" => [{ "attributes" => { "POSITION" => 0, "JOINTS_0" => 1, "WEIGHTS_0" => 2 } }] }
      ],
      "skins" => [{ "joints" => [1], "skeleton" => 1, "inverseBindMatrices" => 3 }],
      "nodes" => [{ "name" => "skinned", "mesh" => 0, "skin" => 0 }, { "name" => "joint" }],
      "scenes" => [{ "nodes" => [0, 1] }],
      "scene" => 0
    }

    result = described_class.load(Rgltf.load_json(json, buffers: buffer))
    mesh = result.scene.find("skinned").children.first

    expect(mesh.geometry.attribute(:joints).format).to eq(:uint16x4)
    expect(mesh.skin.joints).to contain_exactly(result.scene.find("joint"))
    expect(mesh.skin.skeleton).to equal(result.scene.find("joint"))
  end

  it "decodes texture color space, sampler state, and KHR texture transforms" do
    source = gltf_json
    source["extensionsUsed"] << "KHR_texture_transform"
    image = Texel::Image.new(
      width: 1, height: 1, channels: 4, dtype: :u8, color_space: :srgb,
      data: [255, 255, 255, 255].pack("C*")
    )
    uri = "data:image/png;base64,#{[Texel.encode(image, :png)].pack("m0")}"
    source["images"] = [{ "uri" => uri }]
    source["samplers"] = [{ "wrapS" => 33_071, "wrapT" => 33_648, "minFilter" => 9_984 }]
    source["textures"] = [{ "source" => 0, "sampler" => 0 }]
    source["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"] = {
      "index" => 0,
      "extensions" => {
        "KHR_texture_transform" => { "offset" => [0.25, 0.5], "scale" => [2.0, 2.0] }
      }
    }

    result = described_class.load(Rgltf.load_json(source, buffers: gltf_buffer))
    material = result.scene.find("animated").children.find { |child| child.is_a?(Stagecraft::Mesh) }.material

    expect(material.map.color_space).to eq(:srgb)
    expect(material.map.sampler.wrap_u).to eq(:clamp_to_edge)
    expect(material.map.sampler.wrap_v).to eq(:mirror_repeat)
    expect(material.map.sampler.mipmap_filter).to eq(:nearest)
    expect(material.uv_transform.to_a).not_to eq(Larb::Mat3.new.to_a)
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
