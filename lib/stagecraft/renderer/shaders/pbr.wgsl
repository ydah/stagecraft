//#include "common.wgsl"

const PI = 3.14159265359;

struct MaterialUniforms {
  base_color: vec4f,
  factors: vec4f,
  emissive: vec4f,
  texture_flags: vec4u,
  emissive_map_flag: u32,
  alpha_cutoff: f32,
  _padding: vec2f,
  uv_sets: vec4u,
  emissive_uv_set: u32,
  _uv_padding0: u32,
  _uv_padding1: u32,
  _uv_padding2: u32,
  base_color_uv_transform: mat3x3f,
  mr_uv_transform: mat3x3f,
  normal_uv_transform: mat3x3f,
  occlusion_uv_transform: mat3x3f,
  emissive_uv_transform: mat3x3f,
};

@group(1) @binding(0) var<uniform> material: MaterialUniforms;
@group(1) @binding(1) var base_color_sampler: sampler;
@group(1) @binding(2) var base_color_map: texture_2d<f32>;
@group(1) @binding(3) var mr_sampler: sampler;
@group(1) @binding(4) var mr_map: texture_2d<f32>;
@group(1) @binding(5) var normal_sampler: sampler;
@group(1) @binding(6) var normal_map: texture_2d<f32>;
@group(1) @binding(7) var occlusion_sampler: sampler;
@group(1) @binding(8) var occlusion_map: texture_2d<f32>;
@group(1) @binding(9) var emissive_sampler: sampler;
@group(1) @binding(10) var emissive_map: texture_2d<f32>;

struct VertexInput {
  @location(0) position: vec3f,
//#if HAS_NORMAL
  @location(1) normal: vec3f,
//#endif
//#if HAS_UV
  @location(2) uv: vec2f,
//#endif
//#if HAS_UV1
  @location(7) uv1: vec2f,
//#endif
//#if HAS_TANGENT
  @location(3) tangent: vec4f,
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
  @location(0) world_position: vec3f,
  @location(1) normal: vec3f,
  @location(2) uv: vec2f,
  @location(3) color: vec4f,
//#if HAS_TANGENT
  @location(4) tangent: vec4f,
//#endif
  @location(5) uv1: vec2f,
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
  output.world_position = world.xyz;
//#if HAS_NORMAL
  var local_normal = input.normal;
//#if SKINNED
  local_normal = (skin * vec4f(local_normal, 0.0)).xyz;
//#endif
  output.normal = normalize((object.normal_matrix * vec4f(local_normal, 0.0)).xyz);
//#else
  output.normal = vec3f(0.0, 1.0, 0.0);
//#endif
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
//#if HAS_TANGENT
  let world_tangent = normalize((object.model * vec4f(input.tangent.xyz, 0.0)).xyz);
  output.tangent = vec4f(world_tangent, input.tangent.w);
//#endif
  return output;
}

fn distribution_ggx(n_dot_h: f32, roughness: f32) -> f32 {
  let a = roughness * roughness;
  let a2 = a * a;
  let denominator = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
  return a2 / max(PI * denominator * denominator, 0.0001);
}

fn geometry_schlick(n_dot_v: f32, roughness: f32) -> f32 {
  let r = roughness + 1.0;
  let k = (r * r) / 8.0;
  return n_dot_v / max(n_dot_v * (1.0 - k) + k, 0.0001);
}

fn fresnel_schlick(cos_theta: f32, f0: vec3f) -> vec3f {
  return f0 + (vec3f(1.0) - f0) * pow(1.0 - cos_theta, 5.0);
}

@fragment fn fs_main(
  input: VertexOutput,
  @builtin(front_facing) front_facing: bool
) -> @location(0) vec4f {
  var base = material.base_color * input.color;
  if (material.texture_flags.x != 0u) {
    let source_uv = select(input.uv, input.uv1, material.uv_sets.x != 0u);
    let uv = (material.base_color_uv_transform * vec3f(source_uv, 1.0)).xy;
    base *= textureSample(base_color_map, base_color_sampler, uv);
  }
//#if ALPHA_MASK
  if (base.a < material.alpha_cutoff) { discard; }
//#endif
  var metallic = material.factors.x;
  var roughness = max(material.factors.y, 0.04);
  if (material.texture_flags.y != 0u) {
    let source_uv = select(input.uv, input.uv1, material.uv_sets.y != 0u);
    let uv = (material.mr_uv_transform * vec3f(source_uv, 1.0)).xy;
    let mr = textureSample(mr_map, mr_sampler, uv);
    metallic *= mr.b;
    roughness *= mr.g;
  }
  var normal = normalize(input.normal);
//#if DOUBLE_SIDED
  normal *= select(-1.0, 1.0, front_facing);
//#endif
  if (material.texture_flags.z != 0u) {
    let source_uv = select(input.uv, input.uv1, material.uv_sets.z != 0u);
    let uv = (material.normal_uv_transform * vec3f(source_uv, 1.0)).xy;
    var mapped = textureSample(normal_map, normal_sampler, uv).xyz * 2.0 - 1.0;
    mapped = vec3f(mapped.xy * material.factors.z, mapped.z);
//#if HAS_TANGENT
    let bitangent = normalize(cross(normal, input.tangent.xyz)) * input.tangent.w;
    normal = normalize(mat3x3f(input.tangent.xyz, bitangent, normal) * mapped);
//#else
    normal = normalize(normal + mapped);
//#endif
  }
  let view_direction = normalize(frame.camera_pos - input.world_position);
  let f0 = mix(vec3f(0.04), base.rgb, metallic);
  var result = frame.ambient * base.rgb * (1.0 - metallic);

  for (var index = 0u; index < frame.light_count; index = index + 1u) {
    let light = lights[index];
    var light_direction = -light.direction;
    var attenuation = 1.0;
    if (light.kind != 0u) {
      let to_light = light.position - input.world_position;
      let distance = length(to_light);
      light_direction = to_light / max(distance, 0.0001);
      let ratio = distance / max(light.range, 0.0001);
      attenuation = pow(clamp(1.0 - pow(ratio, 4.0), 0.0, 1.0), 2.0) /
                    max(distance * distance, 0.0001);
      if (light.kind == 2u) {
        let angle = dot(-light_direction, light.direction);
        attenuation *= smoothstep(light.cone.y, light.cone.x, angle);
      }
    }
    let halfway = normalize(view_direction + light_direction);
    let n_dot_l = max(dot(normal, light_direction), 0.0);
    let n_dot_v = max(dot(normal, view_direction), 0.0);
    let n_dot_h = max(dot(normal, halfway), 0.0);
    let h_dot_v = max(dot(halfway, view_direction), 0.0);
    let fresnel = fresnel_schlick(h_dot_v, f0);
    let specular = distribution_ggx(n_dot_h, roughness) *
                   geometry_schlick(n_dot_v, roughness) *
                   geometry_schlick(n_dot_l, roughness) * fresnel /
                   max(4.0 * n_dot_v * n_dot_l, 0.0001);
    let diffuse = (vec3f(1.0) - fresnel) * (1.0 - metallic) * base.rgb / PI;
    var visibility = 1.0;
    if (light.kind == 0u && index == 0u && object.receive_shadow != 0u) {
      visibility = shadow_visibility(input.world_position);
    }
    result += (diffuse + specular) * light.color * n_dot_l * attenuation * visibility;
  }
  var emissive = material.emissive.rgb * material.emissive.a;
  if (material.emissive_map_flag != 0u) {
    let source_uv = select(input.uv, input.uv1, material.emissive_uv_set != 0u);
    let uv = (material.emissive_uv_transform * vec3f(source_uv, 1.0)).xy;
    emissive *= textureSample(emissive_map, emissive_sampler, uv).rgb;
  }
  if (material.texture_flags.w != 0u) {
    let source_uv = select(input.uv, input.uv1, material.uv_sets.w != 0u);
    let uv = (material.occlusion_uv_transform * vec3f(source_uv, 1.0)).xy;
    result *= mix(1.0, textureSample(occlusion_map, occlusion_sampler, uv).r,
                  material.factors.w);
  }
  return vec4f(result + emissive, base.a);
}
