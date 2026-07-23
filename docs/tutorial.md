# Learn Stagecraft

This tutorial builds the mental model behind Stagecraft from the scene graph up
to the WebGPU frame. Every section corresponds to a runnable file in
[`examples/`](../examples/README.md).

## 1. The frame

A Stagecraft application has four moving parts:

1. A `Scene` owns a hierarchy of nodes.
2. A `Camera` turns world positions into WebGPU clip coordinates.
3. A `Renderer` collects visible meshes and encodes render passes.
4. `App` owns the window and supplies a clamped delta time.

```ruby
app.run do |dt|
  update_simulation(dt)
  app.renderer.render(scene, camera)
end
```

The render call performs world-matrix resolution, frustum culling, queue
sorting, uniform upload, shadow rendering, HDR rendering, and ACES tone mapping.
The surface is presented only after all callbacks have encoded their work.

## 2. Coordinates and transforms

Stagecraft uses `larb` values throughout. A node exposes observable position,
rotation, and scale values:

```ruby
node.position.set(1, 2, 3)
node.rotation.rotate_y!(Math::PI / 4)
node.scale.set(2, 2, 2)
```

The local transform is composed as translation × rotation × scale. A child's
world transform is its parent world transform multiplied by its local
transform. Version stamps make this lazy: unchanged branches do not recompute
their matrices.

Use `add`, `remove`, `traverse`, and `find` to work with a hierarchy:

```ruby
solar_system.add(sun, orbit)
orbit.add(planet)
planet = solar_system.find("planet")
```

Adding an existing child detaches it from its previous parent. Cycles are
rejected.

## 3. Cameras

Perspective cameras use degrees for vertical field of view:

```ruby
camera = Stagecraft::Cameras::Perspective.new(
  fov: 60, aspect: 16.0 / 9.0, near: 0.1, far: 1_000
)
camera.position.set(0, 2, 5)
camera.look_at(Larb::Vec3.new)
```

Orthographic cameras use explicit view extents:

```ruby
camera = Stagecraft::Cameras::Orthographic.new(
  left: -4, right: 4, top: 2.25, bottom: -2.25,
  near: 0.1, far: 100
)
```

Both projections map depth to WebGPU NDC z ∈ [0, 1]. Update a perspective
camera's `aspect` after a drawable-size change. The gallery helper demonstrates
the resize callback.

`Controls::Orbit` can rotate, pan, and zoom a camera with exponential damping:

```ruby
controls = Stagecraft::Controls::Orbit.new(camera, app.window)
app.run do |dt|
  controls.update(dt)
  app.renderer.render(scene, camera)
end
```

## 4. Geometry

A geometry is a set of packed vertex attributes plus an optional index buffer:

```ruby
geometry = Stagecraft::Geometry.new
geometry.set_attribute(
  :position,
  data: [0, 1, 0, -1, -1, 0, 1, -1, 0].pack("e*"),
  format: :float32x3,
  count: 3
)
geometry.compute_normals!
```

Supported attribute names are `position`, `normal`, `uv`, `uv1`, `tangent`,
`color`, `joints`, and `weights`. Supported primitive topologies are points,
lines, line strips, triangle lists, and triangle strips.

Changing an attribute's packed `data` increments the owning geometry version,
so its GPU buffers are replaced on the next render. Bounds are calculated
lazily from float32x3 positions.

The `Geometries` module includes box, plane, sphere, cylinder, and torus
builders. Their indexed triangles are counter-clockwise on the front face.

## 5. Materials

### Unlit

Unlit materials return their color without lighting:

```ruby
material = Stagecraft::Materials::Unlit.new(
  color: "#448aff",
  opacity: 0.8,
  transparent: true
)
```

### Metallic-roughness PBR

PBR combines Lambert diffuse with GGX / Smith / Fresnel-Schlick specular:

```ruby
material = Stagecraft::Materials::PBR.new(
  base_color: "#eceff1",
  metallic: 0.75,
  roughness: 0.2,
  emissive: "#ff6d00",
  emissive_strength: 0.1
)
```

Metallic and roughness are clamped API values in the 0..1 range. PBR supports
base color, metallic-roughness, normal, occlusion, and emissive maps.

Opaque meshes are sorted front-to-back by pipeline and material. Transparent
meshes are sorted back-to-front after `render_order`. Use `depth_write: false`
for layered alpha-blended surfaces.

## 6. Lights and shadows

Ambient light contributes a constant scene term. Directional, point, and spot
lights are packed into a storage buffer every frame:

```ruby
scene.add(Stagecraft::Lights::Ambient.new(intensity: 0.2))

sun = Stagecraft::Lights::Directional.new(
  color: "#fff5e1",
  intensity: 4.0,
  cast_shadow: true
)
sun.position.set(4, 8, 5)
sun.look_at(Larb::Vec3.new)
scene.add(sun)
```

The first shadow-casting directional light renders a depth32float map. The main
PBR pass samples it with 3×3 percentage-closer filtering. Set
`mesh.cast_shadow` on occluders and `mesh.receive_shadow` on receivers.

Point and spot lights use the glTF punctual-light attenuation curve. Their
`range` avoids spending light outside a useful radius.

## 7. Textures

`Texture.load` delegates decoding to texel:

```ruby
albedo = Stagecraft::Texture.load(
  "albedo.png",
  channels: 4,
  color_space: :srgb
)
material.base_color_map = albedo
```

Request four channels because WebGPU has no three-channel sampled format.
Texel builds mip levels and Stagecraft copies them with WebGPU row alignment.
Color maps and emissive maps should be sRGB; data maps should be linear.

Sampler state is immutable:

```ruby
sampler = Stagecraft::Textures::SamplerState.new(
  wrap_u: :repeat,
  wrap_v: :repeat,
  mag_filter: :linear,
  min_filter: :linear,
  mipmap_filter: :linear
)
```

## 8. glTF assets

```ruby
result = Stagecraft::Loaders::GLTF.load("robot.glb")
scene.add(result.scene)
```

The result contains the default `scene`, every converted `scene`, all
`animations`, and converted `cameras`. Mesh primitives become child Mesh
objects so each primitive can keep its own material and topology.

The loader passes compatible packed accessors directly into Geometry. WebGPU
does not support u8 indices, so those are expanded to u32. glTF line loops and
triangle fans are expanded to supported indexed topologies.

KHR_materials_unlit, KHR_materials_emissive_strength,
KHR_texture_transform, and KHR_lights_punctual are converted. Images are
decoded by texel.

## 9. Skinning and animation

A skin stores joint nodes and inverse-bind matrices. Each frame the renderer
calculates mesh-local joint matrices and uploads them to bind group 2:

```text
inverse_bind × joint.world_matrix × mesh.world_matrix.inverse
```

The vertex shader blends four matrices using the `joints` and `weights`
attributes.

Animation clips group tracks. A mixer resolves track targets once and advances
every playing action:

```ruby
mixer = Stagecraft::Animation::Mixer.new(result.scene)
walk = mixer.play(result.animations.fetch(0), loop: :repeat)
walk.weight = 0.8

app.run do |dt|
  mixer.update(dt)
  renderer.render(scene, camera)
end
```

Use `loop: :once`, `:repeat`, or `:ping_pong`. `fade_in:` raises an action's
weight from zero to one. Translation and scale use component interpolation;
rotations use slerp; glTF cubic spline tracks use Hermite tangents.

## 10. Custom WGSL

Custom shaders define `vs_main` and `fs_main`, and include the engine common
bindings:

```wgsl
//#include "common.wgsl"

struct VertexInput {
  @location(0) position: vec3f,
};

@vertex fn vs_main(input: VertexInput) -> @builtin(position) vec4f {
  return frame.view_proj * object.model * vec4f(input.position, 1.0);
}

@fragment fn fs_main() -> @location(0) vec4f {
  return material.tint;
}
```

The associated Ruby material supplies the group 1 layout:

```ruby
Stagecraft::Materials::Shader.new(
  wgsl: source,
  uniforms: { tint: Stagecraft::Color.new("#ff4081") }
)
```

Numeric, color, larb vector / quaternion / matrix, numeric array, and Texture
values are supported. The packer inserts WGSL padding and generates
`MaterialUniforms`. Texture values become paired sampler and texture bindings.

The stable binding contract is:

| Group | Content |
|---|---|
| 0 | frame uniform, light storage, shadow map and sampler |
| 1 | material uniform, material textures and samplers |
| 2 | dynamic object uniform and joint storage |

## 11. Picking and physics

Create a ray from normalized device coordinates and intersect scene bounds:

```ruby
ray = Stagecraft::Raycaster.new
ray.set_from_camera(pointer_x, pointer_y, camera)
hits = ray.intersect(scene)
```

Hits are nearest-first and expose object, distance, and world point.

`PhysicsBinding` is deliberately duck typed:

```ruby
binding = Stagecraft::PhysicsBinding.new
binding.bind(mesh, rigid_body)
binding.sync!(interpolation_alpha)
```

The body only needs `position` and quaternion `rotation`.

## 12. Offscreen and UI integration

Use `Renderer.offscreen` when no surface is needed. `Frame#read_pixels` returns
an sRGB, four-channel texel image.

For overlays, use `on_after_render`. The callback receives the shared command
encoder and HDR target view before tone mapping. The renderer exposes the same
`device`, `queue`, and `surface_format` required by a WebGPU UI backend.

## 13. Lifetime and performance

Geometry, texture, material, and world transforms use version keys. Pipeline
objects use a 256-entry LRU keyed by material type, shader features, vertex
layout, blending, depth, culling, sample count, target format, and pass.

Object uniforms occupy 256-byte dynamic slots in a three-frame ring buffer.
Lights and joints use storage buffers. CPU resources must be disposed
explicitly when their GPU allocations are no longer needed:

```ruby
geometry.dispose
texture.dispose
renderer.dispose
```

Set `STAGECRAFT_DEBUG=1` while developing. `renderer.stats.to_h` always exposes
draw calls, triangles, live buffers, live textures, live pipelines, visible
objects, and culled objects.
