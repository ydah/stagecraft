# Stagecraft v1 public API

The following namespaces and entry points form the v1 API.

## Application and rendering

- `Stagecraft::App`
- `Stagecraft::Renderer`
- `Stagecraft::Renderer.offscreen`
- `Stagecraft::Renderer::Frame#read_pixels`
- `Stagecraft::Renderer::Stats`
- `Stagecraft::Window::Adapter`
- `Stagecraft::Window::Sdl3`
- `Stagecraft::Window::Glfw`

## Scene graph

- `Stagecraft::Node`
- `Stagecraft::MatrixNode`
- `Stagecraft::Scene`
- `Stagecraft::Mesh`
- `Stagecraft::Geometry`
- `Stagecraft::Attribute`
- `Stagecraft::Raycaster`
- `Stagecraft::Skin`

## Cameras and controls

- `Stagecraft::Cameras::Camera`
- `Stagecraft::Cameras::Perspective`
- `Stagecraft::Cameras::Orthographic`
- `Stagecraft::Controls::Orbit`

The longer `PerspectiveCamera`, `OrthographicCamera`, and `OrbitControls`
constants are compatibility aliases.

## Lights

- `Stagecraft::Lights::Ambient`
- `Stagecraft::Lights::Directional`
- `Stagecraft::Lights::Point`
- `Stagecraft::Lights::Spot`
- `Stagecraft::Lights::ShadowConfig`

## Materials and textures

- `Stagecraft::Materials::Base`
- `Stagecraft::Materials::Unlit`
- `Stagecraft::Materials::PBR`
- `Stagecraft::Materials::Shader`
- `Stagecraft::Textures::Texture`
- `Stagecraft::Textures::CubeTexture`
- `Stagecraft::Textures::SamplerState`
- `Stagecraft::Texture`

## Assets and animation

- `Stagecraft::Loaders::GLTF.load`
- `Stagecraft::Loaders::GLTF::Result`
- `Stagecraft::Animation::Track`
- `Stagecraft::Animation::Clip`
- `Stagecraft::Animation::Action`
- `Stagecraft::Animation::Mixer`

## Math-facing helpers

- `Stagecraft::Color`
- `Stagecraft::ObservedVec3`
- `Stagecraft::ObservedQuat`
- `Stagecraft::Bounding::Box3`
- `Stagecraft::Bounding::Sphere`
- `Stagecraft::Bounding::Plane`
- `Stagecraft::Bounding::Frustum`

## Primitive geometry and integration

- `Stagecraft::Geometries.box`
- `Stagecraft::Geometries.plane`
- `Stagecraft::Geometries.sphere`
- `Stagecraft::Geometries.cylinder`
- `Stagecraft::Geometries.torus`
- `Stagecraft::PhysicsBinding`

Nested renderer implementation types are public for inspection but are not part
of the compatibility contract.
