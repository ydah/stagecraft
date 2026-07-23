# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "06 — Transparent sorting")
colors = %w[#ff174480 #00e5ff80 #76ff0380]
colors.each_with_index do |color, index|
  material = Stagecraft::Materials::Unlit.new(
    color:,
    transparent: true,
    alpha_mode: :blend,
    depth_write: false
  )
  plane = Stagecraft::Mesh.new(Stagecraft::Geometries.plane(2.4, 2.4), material)
  plane.position.set((index - 1) * 0.6, 0, -index * 0.5)
  demo.scene.add(plane)
end
demo.camera.position.set(0, 0, 5)
demo.run
