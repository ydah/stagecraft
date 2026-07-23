# Stagecraft

Stagecraft is a three.js-like scene graph and WebGPU renderer for Ruby. It
combines `wgpu`, `larb`, `rgltf`, and `texel` behind a compact
Scene / Mesh / Material / Camera / Renderer API.

The renderer uses WebGPU zero-to-one depth, PBR metallic-roughness materials,
HDR rendering with ACES tone mapping, frustum culling, transparent and opaque
queues, MSAA, directional shadow maps, skinning, and glTF animation.

## Requirements

- Ruby 3.2 or newer
- A WebGPU backend supported by the `wgpu` gem
- SDL3 for the default window adapter

## Installation

Add Stagecraft to your bundle:

```sh
bundle add stagecraft
```

Or install it directly:

```sh
gem install stagecraft
```

## First scene

```ruby
require "stagecraft"

app = Stagecraft::App.new(title: "Hello Stagecraft", width: 1280, height: 720)

scene = Stagecraft::Scene.new
scene.background = Stagecraft::Color.new(0.05, 0.06, 0.08)
scene.add(Stagecraft::Lights::Ambient.new(intensity: 0.25))

sun = Stagecraft::Lights::Directional.new(intensity: 3.0, cast_shadow: true)
sun.position.set(4, 8, 4)
sun.look_at(Larb::Vec3.new)
scene.add(sun)

cube = Stagecraft::Mesh.new(
  Stagecraft::Geometries.box(1, 1, 1),
  Stagecraft::Materials::PBR.new(
    base_color: "#e91e63",
    roughness: 0.4,
    metallic: 0.1
  )
)
cube.cast_shadow = true
scene.add(cube)

camera = Stagecraft::Cameras::Perspective.new(
  fov: 60,
  aspect: app.aspect,
  near: 0.1,
  far: 100
)
camera.position.set(0, 2, 5)
controls = Stagecraft::Controls::Orbit.new(camera, app.window)

app.run do |dt|
  controls.update(dt)
  cube.rotation.rotate_y!(dt)
  app.renderer.render(scene, camera)
end
```

`App#run` clamps delta time to 100 ms, polls the window at vsync cadence, and
disposes its renderer and window when the loop ends.

## glTF and animation

`Loaders::GLTF` accepts a `.gltf` / `.glb` path or an existing
`Rgltf::Document`. It converts scenes, cameras, punctual lights, materials,
textures, skins, and animation channels:

```ruby
model = Stagecraft::Loaders::GLTF.load("assets/robot.glb")
scene.add(model.scene)

mixer = Stagecraft::Animation::Mixer.new(model.scene)
mixer.play(model.animations.first, loop: :repeat, fade_in: 0.25)

app.run do |dt|
  mixer.update(dt)
  app.renderer.render(scene, camera)
end
```

glTF `LINEAR`, `STEP`, and `CUBICSPLINE` tracks are supported. Multiple actions
blend by weight; rotations use normalized quaternion blending.

## Materials and textures

Stagecraft includes PBR, Unlit, and custom WGSL materials. Base color and
emissive textures are uploaded as sRGB; metallic-roughness, normal, and
occlusion textures stay linear. KHR texture transforms are carried into the
material uniforms.

```ruby
texture = Stagecraft::Texture.load(
  "assets/albedo.png",
  channels: 4,
  color_space: :srgb
)
material = Stagecraft::Materials::PBR.new(
  base_color_map: texture,
  metallic: 0.0,
  roughness: 0.7
)
```

`Materials::Shader` accepts a WGSL string or any object responding to
`#to_wgsl`. Stagecraft injects frame and object bindings and packs the uniform
hash according to WGSL alignment:

```ruby
material = Stagecraft::Materials::Shader.new(
  wgsl: File.read("effect.wgsl"),
  uniforms: {
    tint: Stagecraft::Color.new("#7c4dff"),
    speed: 2.0
  }
)
```

Custom shaders own bind group 1. Frame data is group 0 and object / skin data
is group 2. See [the tutorial](docs/tutorial.md#custom-wgsl) for the complete
contract.

## Headless rendering

An offscreen renderer returns a readable frame backed by a `Texel::Image`:

```ruby
renderer = Stagecraft::Renderer.offscreen(width: 512, height: 512, msaa: 4)
frame = renderer.render(scene, camera)
Texel.save(frame.read_pixels, "frame.png")
renderer.dispose
```

## Integration hooks

The renderer exposes `device`, `queue`, and `surface_format`. UI renderers such
as imgui-ruby can append commands after the main pass:

```ruby
renderer.on_after_render do |encoder, hdr_target_view|
  overlay.render(encoder, hdr_target_view, stats: renderer.stats)
end
```

`PhysicsBinding` connects any body exposing `position` and quaternion
`rotation`. `Materials::Shader` accepts rlsl-like objects through `#to_wgsl`.

## Resource lifetime and diagnostics

GPU resources are versioned and cached. Call `dispose` on mutable geometry and
textures when they are no longer needed, and always dispose standalone
renderers. `App` handles renderer shutdown automatically.

Set `STAGECRAFT_DEBUG=1` to report live render statistics once per second and
warn about cached resources remaining at renderer shutdown:

```sh
STAGECRAFT_DEBUG=1 bundle exec ruby examples/01_spinning_cube.rb
```

## Window adapters

SDL3 is the portable default. `window: :glfw` is available when the application
supplies the platform-specific WebGPU `surface_factory`, because glfw-ruby does
not expose a portable WebGPU surface handle.

An existing object implementing the window adapter protocol can be passed as
`window:`. It must provide `poll_events`, `should_close?`, `drawable_size`,
`create_surface(instance)`, and `close`.

## Learn and explore

- [Learn Stagecraft tutorial](docs/tutorial.md)
- [v1 public API map](docs/api.md)
- [20 runnable gallery examples](examples/README.md)

Use `STAGECRAFT_SMOKE=1` to close a window example after one frame.

## Development

```sh
bin/setup
bundle exec rake spec
bundle exec rake build
```

GPU-free unit tests cover scene traversal, bounds, culling, sorting, shader
composition, uniform layout, glTF conversion, and animation. Offscreen WebGPU
rendering can be used for platform integration tests.

## License

Stagecraft is released under the [MIT License](LICENSE.txt).
