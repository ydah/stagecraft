# frozen_string_literal: true

require_relative "support/demo"
require "rgltf"

positions = [-1, -1, 0, 1, -1, 0, 0, 1, 0].pack("e*")
json = {
  "asset" => { "version" => "2.0" },
  "buffers" => [{ "byteLength" => positions.bytesize }],
  "bufferViews" => [{ "buffer" => 0, "byteLength" => positions.bytesize }],
  "accessors" => [
    { "bufferView" => 0, "componentType" => 5_126, "count" => 3, "type" => "VEC3" }
  ],
  "meshes" => [{ "primitives" => [{ "attributes" => { "POSITION" => 0 } }] }],
  "nodes" => [{ "name" => "triangle", "mesh" => 0 }],
  "scenes" => [{ "nodes" => [0] }],
  "scene" => 0
}
document = Rgltf.load_json(json, buffers: positions)
model = Stagecraft::Loaders::GLTF.load(document)
demo = StagecraftExamples::Demo.new(title: "09 — glTF loader")
demo.scene.add(model.scene)
demo.camera.position.set(0, 0, 4)
demo.run
