# frozen_string_literal: true

require_relative "support/demo"

wgsl = <<~WGSL
  //#include "common.wgsl"
  struct VertexInput { @location(0) position: vec3f };
  struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) local: vec3f,
  };
  @vertex fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    output.position = frame.view_proj * object.model * vec4f(input.position, 1.0);
    output.local = input.position;
    return output;
  }
  @fragment fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let pulse = 0.55 + 0.45 * sin(frame.time * material.speed);
    return vec4f(material.tint.rgb * pulse, material.tint.a);
  }
WGSL

demo = StagecraftExamples::Demo.new(title: "08 — Shader material")
material = Stagecraft::Materials::Shader.new(
  wgsl:,
  uniforms: { tint: Stagecraft::Color.new("#7c4dff"), speed: 3.0 }
)
demo.scene.add(Stagecraft::Mesh.new(Stagecraft::Geometries.torus, material))
demo.run
