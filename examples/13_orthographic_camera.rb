# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "13 — Orthographic camera", controls: false)
demo.camera = Stagecraft::Cameras::Orthographic.new(
  left: -4, right: 4, top: 2.25, bottom: -2.25, near: 0.1, far: 20
)
demo.camera.position.z = 6
7.times do |index|
  square = Stagecraft::Mesh.new(
    Stagecraft::Geometries.plane(0.8, 0.8),
    Stagecraft::Materials::Unlit.new(color: Stagecraft::Color.new(index / 7.0, 0.5, 1.0))
  )
  square.position.x = index - 3
  demo.scene.add(square)
end
demo.run
