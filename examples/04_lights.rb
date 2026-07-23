# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "04 — Light types")
demo.scene.add(Stagecraft::Lights::Ambient.new(intensity: 0.08))
point = Stagecraft::Lights::Point.new(color: "#ff5252", intensity: 25, range: 8)
point.position.set(-2, 2, 2)
spot = Stagecraft::Lights::Spot.new(
  color: "#40c4ff", intensity: 35, range: 10,
  inner_angle: 0.2, outer_angle: 0.55
)
spot.position.set(2, 3, 3)
spot.look_at(Larb::Vec3.new)
demo.scene.add(point, spot)
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.sphere(1.2),
    Stagecraft::Materials::PBR.new(base_color: "#eeeeee", roughness: 0.45)
  )
)
demo.run
