# frozen_string_literal: true

require_relative "support/demo"
require "texel"

pixels = [
  255, 255, 255, 255, 20, 20, 20, 255,
  20, 20, 20, 255, 255, 255, 255, 255
].pack("C*")
image = Texel::Image.new(
  width: 2, height: 2, channels: 4, dtype: :u8, color_space: :srgb, data: pixels
)
texture = Stagecraft::Texture.new(image, color_space: :srgb)
demo = StagecraftExamples::Demo.new(title: "07 — Texture")
demo.light!
demo.scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.box(2, 2, 2),
    Stagecraft::Materials::PBR.new(base_color_map: texture, roughness: 0.7)
  )
)
demo.run
