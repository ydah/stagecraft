# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "03 — PBR material grid")
demo.light!
5.times do |row|
  5.times do |column|
    material = Stagecraft::Materials::PBR.new(
      base_color: "#d6d9df",
      metallic: column / 4.0,
      roughness: [row / 4.0, 0.04].max
    )
    sphere = Stagecraft::Mesh.new(Stagecraft::Geometries.sphere(0.38), material)
    sphere.position.set((column - 2) * 0.9, (row - 2) * 0.9, 0)
    demo.scene.add(sphere)
  end
end
demo.camera.position.set(0, 0, 7)
demo.run
