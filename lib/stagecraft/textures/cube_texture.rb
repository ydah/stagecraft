# frozen_string_literal: true

module Stagecraft
  module Textures
    class CubeTexture < Texture
      attr_reader :faces

      def initialize(faces, **)
        raise ArgumentError, "cube texture requires six faces" unless faces.length == 6

        @faces = faces.freeze
        super(nil, **)
      end
    end
  end
end
