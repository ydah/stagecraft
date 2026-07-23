# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "02 — Primitives")
demo.light!
geometries = [
  Stagecraft::Geometries.box,
  Stagecraft::Geometries.sphere,
  Stagecraft::Geometries.cylinder(0.7, 0.7, 1.5),
  Stagecraft::Geometries.torus
]
geometries.each_with_index do |geometry, index|
  mesh = Stagecraft::Mesh.new(
    geometry,
    Stagecraft::Materials::PBR.new(base_color: ["#ff5252", "#40c4ff", "#69f0ae", "#ffd740"][index])
  )
  mesh.position.x = (index - 1.5) * 2.0
  demo.scene.add(mesh)
end
demo.run
