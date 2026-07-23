# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "12 — Orbit controls")
demo.light!
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.torus(1.2, 0.35),
    Stagecraft::Materials::PBR.new(base_color: "#18ffff", metallic: 0.65, roughness: 0.22)
  )
)
demo.run
