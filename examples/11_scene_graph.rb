# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "11 — Scene graph")
demo.light!
pivot = Stagecraft::Node.new(name: "pivot")
sun = Stagecraft::Mesh.new(
  Stagecraft::Geometries.sphere(0.7),
  Stagecraft::Materials::PBR.new(base_color: "#ffd740", emissive: "#ffab00", emissive_strength: 0.5)
)
moon = Stagecraft::Mesh.new(
  Stagecraft::Geometries.sphere(0.25),
  Stagecraft::Materials::PBR.new(base_color: "#b0bec5")
)
moon.position.x = 2.0
pivot.add(sun, moon)
demo.scene.add(pivot)
demo.update { |dt| pivot.rotation.rotate_y!(dt) }
demo.run
