# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "01 — Spinning cube")
demo.light!
cube = Stagecraft::Mesh.new(
  Stagecraft::Geometries.box,
  Stagecraft::Materials::PBR.new(base_color: "#e91e63", roughness: 0.35, metallic: 0.15)
)
demo.scene.add(cube)
demo.update { |dt| cube.rotation.rotate_y!(dt) }
demo.run
