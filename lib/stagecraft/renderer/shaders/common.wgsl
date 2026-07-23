struct FrameUniforms {
  view_proj: mat4x4f,
  camera_pos: vec3f,
  time: f32,
  ambient: vec3f,
  light_count: u32,
  light_vp: mat4x4f,
};

struct Light {
  kind: u32,
  color: vec3f,
  position: vec3f,
  direction: vec3f,
  range: f32,
  cone: vec2f,
};

struct ObjectUniforms {
  model: mat4x4f,
  normal_matrix: mat4x4f,
  receive_shadow: u32,
};

@group(0) @binding(0) var<uniform> frame: FrameUniforms;
@group(0) @binding(1) var<storage, read> lights: array<Light>;
@group(0) @binding(2) var shadow_map: texture_depth_2d;
@group(0) @binding(3) var shadow_sampler: sampler_comparison;
@group(2) @binding(0) var<uniform> object: ObjectUniforms;
@group(2) @binding(1) var<storage, read> joints: array<mat4x4f>;

fn shadow_visibility(world_position: vec3f) -> f32 {
  let projected = frame.light_vp * vec4f(world_position, 1.0);
  let uvz = projected.xyz / projected.w;
  let uv = vec2f(uvz.x * 0.5 + 0.5, 0.5 - uvz.y * 0.5);
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || uvz.z > 1.0) {
    return 1.0;
  }
  var visibility = 0.0;
  let dimensions = vec2f(textureDimensions(shadow_map));
  for (var y = -1; y <= 1; y = y + 1) {
    for (var x = -1; x <= 1; x = x + 1) {
      let offset = vec2f(f32(x), f32(y)) / dimensions;
      visibility += textureSampleCompare(shadow_map, shadow_sampler, uv + offset, uvz.z - 0.001);
    }
  }
  return visibility / 9.0;
}
