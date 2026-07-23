# frozen_string_literal: true

module Stagecraft
  class Skin
    attr_reader :joints, :inverse_bind_matrices, :skeleton

    def initialize(joints:, inverse_bind_matrices: nil, skeleton: nil)
      @joints = joints.freeze
      @inverse_bind_matrices = inverse_bind_matrices || Array.new(joints.length) { Larb::Mat4.identity }
      @skeleton = skeleton
      unless @inverse_bind_matrices.length == joints.length
        raise ArgumentError, "inverse bind matrix count must match joint count"
      end
    end

    def joint_matrices(mesh)
      mesh_inverse = mesh.world_matrix.inverse
      joints.each_with_index.map do |joint, index|
        inverse_bind_matrices[index] * joint.world_matrix * mesh_inverse
      end
    end
  end
end
