# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "stagecraft"

module StagecraftExamples
  class Demo
    attr_reader :app, :scene
    attr_accessor :camera

    def initialize(title:, width: 960, height: 540, msaa: 4, window: :sdl3, controls: true)
      @app = Stagecraft::App.new(title:, width:, height:, msaa:, window:)
      @scene = Stagecraft::Scene.new
      @scene.background = "#10141d"
      @camera = Stagecraft::Cameras::Perspective.new(
        fov: 55, aspect: app.aspect, near: 0.1, far: 200
      )
      @camera.position.set(0, 2, 6)
      @controls_enabled = controls
      @updates = []
      app.window.on_resize do |next_width, next_height|
        camera.aspect = next_width.to_f / [next_height, 1].max if camera.respond_to?(:aspect=)
      end
    end

    def light!
      scene.add(Stagecraft::Lights::Ambient.new(intensity: 0.3))
      sun = Stagecraft::Lights::Directional.new(intensity: 3.0)
      sun.position.set(4, 7, 5)
      scene.add(sun)
      sun
    end

    def update(&block)
      @updates << block
      self
    end

    def run
      controls = Stagecraft::Controls::Orbit.new(camera, app.window) if @controls_enabled
      app.run do |dt|
        controls&.update(dt)
        @updates.each { |callback| callback.call(dt) }
        app.renderer.render(scene, camera)
      end
    end
  end
end
