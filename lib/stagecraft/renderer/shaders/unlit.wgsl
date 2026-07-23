//#include "common.wgsl"

struct MaterialUniforms {
  color: vec4f,
  use_map: u32,
  alpha_cutoff: f32,
  _padding: vec2f,
  uv_transform: mat3x3f,
};

@group(1) @binding(0) var<uniform> material: MaterialUniforms;
@group(1) @binding(1) var material_sampler: sampler;
@group(1) @binding(2) var color_map: texture_2d<f32>;

struct VertexInput {
  @location(0) position: vec3f,
//#if HAS_UV
  @location(2) uv: vec2f,
//#endif
//#if SKINNED
  @location(5) joint: vec4u,
  @location(6) weight: vec4f,
//#endif
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};

@vertex fn vs_main(input: VertexInput) -> VertexOutput {
  var output: VertexOutput;
  var local_position = vec4f(input.position, 1.0);
//#if SKINNED
  let skin = input.weight.x * joints[input.joint.x] +
             input.weight.y * joints[input.joint.y] +
             input.weight.z * joints[input.joint.z] +
             input.weight.w * joints[input.joint.w];
  local_position = skin * local_position;
//#endif
  let world = object.model * local_position;
  output.position = frame.view_proj * world;
//#if HAS_UV
  output.uv = (material.uv_transform * vec3f(input.uv, 1.0)).xy;
//#else
  output.uv = vec2f(0.0);
//#endif
  return output;
}

@fragment fn fs_main(input: VertexOutput) -> @location(0) vec4f {
  var color = material.color;
  if (material.use_map != 0u) {
    color *= textureSample(color_map, material_sampler, input.uv);
  }
//#if ALPHA_MASK
  if (color.a < material.alpha_cutoff) { discard; }
//#endif
  return color;
}
