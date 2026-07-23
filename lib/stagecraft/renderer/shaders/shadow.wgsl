struct FrameUniforms {
  view_proj: mat4x4f,
  camera_pos: vec3f,
  time: f32,
  ambient: vec3f,
  light_count: u32,
  light_vp: mat4x4f,
};

struct ObjectUniforms {
  model: mat4x4f,
  normal_matrix: mat4x4f,
};

@group(0) @binding(0) var<uniform> frame: FrameUniforms;
@group(2) @binding(0) var<uniform> object: ObjectUniforms;
@group(2) @binding(1) var<storage, read> joints: array<mat4x4f>;

struct VertexInput {
  @location(0) position: vec3f,
//#if SKINNED
  @location(5) joint: vec4u,
  @location(6) weight: vec4f,
//#endif
};

@vertex fn vs_main(input: VertexInput) -> @builtin(position) vec4f {
  var local_position = vec4f(input.position, 1.0);
//#if SKINNED
  let skin = input.weight.x * joints[input.joint.x] +
             input.weight.y * joints[input.joint.y] +
             input.weight.z * joints[input.joint.z] +
             input.weight.w * joints[input.joint.w];
  local_position = skin * local_position;
//#endif
  return frame.light_vp * object.model * local_position;
}
