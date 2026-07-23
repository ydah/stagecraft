# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "14 — Raycaster")
mesh = Stagecraft::Mesh.new(
  Stagecraft::Geometries.sphere,
  Stagecraft::Materials::Unlit.new(color: "#69f0ae")
)
demo.scene.add(mesh)
raycaster = Stagecraft::Raycaster.new
raycaster.set_from_camera(0.0, 0.0, demo.camera)
warn "center ray hits: #{raycaster.intersect(demo.scene).map { |hit| hit.object.name || "mesh" }.join(", ")}"
demo.run
