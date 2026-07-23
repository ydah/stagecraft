# frozen_string_literal: true

require_relative "support/demo"

Body = Struct.new(:position, :rotation)
demo = StagecraftExamples::Demo.new(title: "17 — Physics binding")
demo.light!
mesh = Stagecraft::Mesh.new(
  Stagecraft::Geometries.box,
  Stagecraft::Materials::PBR.new(base_color: "#ff6d00")
)
body = Body.new(Larb::Vec3.new, Larb::Quat.new)
binding = Stagecraft::PhysicsBinding.new.bind(mesh, body)
elapsed = 0.0
demo.scene.add(mesh)
demo.update do |dt|
  elapsed += dt
  body.position = Larb::Vec3.new(Math.sin(elapsed) * 2.0, 0, 0)
  body.rotation = Larb::Quat.from_axis_angle(Larb::Vec3.up, elapsed)
  binding.sync!(1.0)
end
demo.run
