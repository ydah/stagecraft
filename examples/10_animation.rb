# frozen_string_literal: true

require_relative "support/demo"

demo = StagecraftExamples::Demo.new(title: "10 — Animation mixer")
demo.light!
cube = Stagecraft::Mesh.new(
  Stagecraft::Geometries.box,
  Stagecraft::Materials::PBR.new(base_color: "#00b0ff")
)
demo.scene.add(cube)
track = Stagecraft::Animation::Track.new(
  times: [0.0, 1.0, 2.0],
  values: [-2, 0, 0, 2, 0, 0, -2, 0, 0],
  target: cube,
  target_path: :translation
)
mixer = Stagecraft::Animation::Mixer.new(demo.scene)
mixer.play(Stagecraft::Animation::Clip.new(name: "slide", tracks: [track]))
demo.update { |dt| mixer.update(dt) }
demo.run
