//#include "common.wgsl"

struct MaterialUniforms {
  color: vec4f,
  use_map: u32,
  alpha_cutoff: f32,
  uv_set: u32,
  _padding: f32,
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
//#if HAS_UV1
  @location(7) uv1: vec2f,
//#endif
//#if HAS_VERTEX_COLOR
//#if COLOR_VEC3
  @location(4) color: vec3f,
//#else
  @location(4) color: vec4f,
//#endif
//#endif
//#if SKINNED
  @location(5) joint: vec4u,
  @location(6) weight: vec4f,
//#endif
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) uv1: vec2f,
  @location(2) color: vec4f,
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
  output.uv = input.uv;
//#else
  output.uv = vec2f(0.0);
//#endif
//#if HAS_UV1
  output.uv1 = input.uv1;
//#else
  output.uv1 = output.uv;
//#endif
//#if HAS_VERTEX_COLOR
//#if COLOR_VEC3
  output.color = vec4f(input.color, 1.0);
//#else
  output.color = input.color;
//#endif
//#else
  output.color = vec4f(1.0);
//#endif
  return output;
}

@fragment fn fs_main(input: VertexOutput) -> @location(0) vec4f {
  var color = material.color * input.color;
  if (material.use_map != 0u) {
    let source_uv = select(input.uv, input.uv1, material.uv_set != 0u);
    let uv = (material.uv_transform * vec3f(source_uv, 1.0)).xy;
    color *= textureSample(color_map, material_sampler, uv);
  }
//#if ALPHA_MASK
  if (color.a < material.alpha_cutoff) { discard; }
//#endif
  return color;
}
