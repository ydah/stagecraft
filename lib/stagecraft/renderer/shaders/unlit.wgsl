//#include "common.wgsl"

struct MaterialUniforms {
  color: vec4f,
  use_map: u32,
  alpha_cutoff: f32,
  _padding: vec2f,
};

@group(1) @binding(0) var<uniform> material: MaterialUniforms;
@group(1) @binding(1) var material_sampler: sampler;
@group(1) @binding(2) var color_map: texture_2d<f32>;

struct VertexInput {
  @location(0) position: vec3f,
//#if HAS_UV
  @location(2) uv: vec2f,
//#endif
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};

@vertex fn vs_main(input: VertexInput) -> VertexOutput {
  var output: VertexOutput;
  let world = object.model * vec4f(input.position, 1.0);
  output.position = frame.view_proj * world;
//#if HAS_UV
  output.uv = input.uv;
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
