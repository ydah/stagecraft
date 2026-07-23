# frozen_string_literal: true

require_relative "support/demo"

# SDL3 is the portable default. Set STAGECRAFT_WINDOW=glfw only when supplying
# the platform-specific WebGPU surface bridge described in the README.
window = ENV.fetch("STAGECRAFT_WINDOW", "sdl3").to_sym
demo = StagecraftExamples::Demo.new(title: "20 — #{window} adapter", window:)
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.box,
    Stagecraft::Materials::Unlit.new(color: "#448aff")
  )
)
demo.run
