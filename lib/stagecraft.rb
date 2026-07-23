# frozen_string_literal: true

require "larb"

require_relative "stagecraft/version"
require_relative "stagecraft/color"
require_relative "stagecraft/core/observed_value"
require_relative "stagecraft/core/bounding"
require_relative "stagecraft/core/node"
require_relative "stagecraft/core/scene"
require_relative "stagecraft/core/mesh"
require_relative "stagecraft/core/attribute"
require_relative "stagecraft/core/geometry"
require_relative "stagecraft/core/raycaster"
require_relative "stagecraft/cameras/camera"
require_relative "stagecraft/cameras/perspective_camera"
require_relative "stagecraft/cameras/orthographic_camera"
require_relative "stagecraft/lights/light"
require_relative "stagecraft/lights/ambient_light"
require_relative "stagecraft/lights/directional_light"
require_relative "stagecraft/lights/point_light"
require_relative "stagecraft/lights/spot_light"
require_relative "stagecraft/materials/material"
require_relative "stagecraft/materials/unlit_material"
require_relative "stagecraft/materials/pbr_material"
require_relative "stagecraft/materials/shader_material"
require_relative "stagecraft/textures/sampler_state"
require_relative "stagecraft/textures/texture"
require_relative "stagecraft/textures/cube_texture"
require_relative "stagecraft/geometries"
require_relative "stagecraft/physics_binding"

module Stagecraft
  class Error < StandardError; end
  class DisposedError < Error; end
end
