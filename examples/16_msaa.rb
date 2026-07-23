# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "16 — 8x MSAA", msaa: 8)
demo.light!
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.torus(1.2, 0.18, radial_segments: 8, tubular_segments: 96),
    Stagecraft::Materials::PBR.new(base_color: "#ffffff", roughness: 0.25)
  )
)
demo.run
