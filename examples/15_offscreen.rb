# frozen_string_literal: true

require_relative "support/demo"
require "texel"

scene = Stagecraft::Scene.new
scene.background = "#263238"
scene.add(
  Stagecraft::Mesh.new(
    Stagecraft::Geometries.box,
    Stagecraft::Materials::Unlit.new(color: "#ff4081")
  )
)
camera = Stagecraft::Cameras::Perspective.new(aspect: 1.0)
camera.position.z = 3
renderer = Stagecraft::Renderer.offscreen(width: 512, height: 512, msaa: 4)
image = renderer.render(scene, camera).read_pixels
destination = ARGV.first || File.expand_path("../tmp/stagecraft-offscreen.png", __dir__)
Dir.mkdir(File.dirname(destination)) unless Dir.exist?(File.dirname(destination))
Texel.save(image, destination)
renderer.dispose
puts destination
