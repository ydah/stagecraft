# frozen_string_literal: true

require_relative "support/demo"

geometry = Stagecraft::Geometry.new
geometry.set_attribute(
  :position,
  data: [0, 1.5, 0, -1.5, -1, 0, 1.5, -1, 0].pack("e*"),
  format: :float32x3,
  count: 3
)
geometry.compute_normals!
demo = StagecraftExamples::Demo.new(title: "18 — Custom geometry")
demo.light!
demo.scene.add(
  Stagecraft::Mesh.new(
    geometry,
    Stagecraft::Materials::PBR.new(base_color: "#d500f9", roughness: 0.55)
  )
)
demo.camera.position.set(0, 0, 5)
demo.run
