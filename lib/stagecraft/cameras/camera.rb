# frozen_string_literal: true

module Stagecraft
  module Cameras
    class Camera < Node
      def view_matrix
        world_matrix.inverse
      end

      def view_projection_matrix
        projection_matrix * view_matrix
      end
    end
  end
end
