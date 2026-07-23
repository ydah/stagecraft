# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "19 — Stats / ImGui hook")
demo.light!
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.sphere,
    Stagecraft::Materials::PBR.new(base_color: "#64ffda")
  )
)

# An imgui-ruby WGPU backend can encode its draw data in this callback. The same
# device and queue are available as demo.app.renderer.device / .queue.
last_report = 0.0
demo.app.renderer.on_after_render do |_encoder, _target_view|
  now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  next unless now - last_report >= 1.0

  warn demo.app.renderer.stats.to_s
  last_report = now
end
demo.run
