# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "05 — Directional shadow")
demo.scene.add(Stagecraft::Lights::Ambient.new(intensity: 0.12))
sun = Stagecraft::Lights::Directional.new(intensity: 4.0, cast_shadow: true)
sun.position.set(4, 8, 5)
sun.look_at(Larb::Vec3.new)
cube = Stagecraft::Mesh.new(
  Stagecraft::Geometries.box,
  Stagecraft::Materials::PBR.new(base_color: "#ffab40", roughness: 0.5)
)
cube.position.y = 0.7
cube.cast_shadow = true
floor = Stagecraft::Mesh.new(
  Stagecraft::Geometries.plane(12, 12),
  Stagecraft::Materials::PBR.new(base_color: "#78909c", roughness: 0.9)
)
floor.rotation.rotate_x!(-Math::PI / 2)
floor.receive_shadow = true
demo.scene.add(sun, cube, floor)
demo.run
