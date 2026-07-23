@group(0) @binding(0) var hdr_texture: texture_2d<f32>;
@group(0) @binding(1) var hdr_sampler: sampler;

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};

@vertex fn vs_main(@builtin(vertex_index) index: u32) -> VertexOutput {
  let positions = array<vec2f, 3>(
    vec2f(-1.0, -1.0),
    vec2f(3.0, -1.0),
    vec2f(-1.0, 3.0)
  );
  var output: VertexOutput;
  output.position = vec4f(positions[index], 0.0, 1.0);
  output.uv = output.position.xy * vec2f(0.5, -0.5) + vec2f(0.5);
  return output;
}

fn aces(color: vec3f) -> vec3f {
  let a = 2.51;
  let b = 0.03;
  let c = 2.43;
  let d = 0.59;
  let e = 0.14;
  return clamp((color * (a * color + b)) / (color * (c * color + d) + e), vec3f(0.0), vec3f(1.0));
}

@fragment fn fs_main(input: VertexOutput) -> @location(0) vec4f {
  var color = aces(textureSample(hdr_texture, hdr_sampler, input.uv).rgb);
//#if ENCODE_SRGB
  color = select(12.92 * color, 1.055 * pow(color, vec3f(1.0 / 2.4)) - 0.055,
                 color > vec3f(0.0031308));
//#endif
  return vec4f(color, 1.0);
}
