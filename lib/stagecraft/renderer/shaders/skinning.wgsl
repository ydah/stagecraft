fn skin_matrix(joint: vec4u, weight: vec4f) -> mat4x4f {
  return weight.x * joints[joint.x] +
         weight.y * joints[joint.y] +
         weight.z * joints[joint.z] +
         weight.w * joints[joint.w];
}
