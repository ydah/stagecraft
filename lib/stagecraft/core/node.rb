# frozen_string_literal: true

module Stagecraft
  class Node
    attr_reader :position, :rotation, :scale, :children, :parent, :world_version
    attr_accessor :name, :visible, :cast_shadow, :receive_shadow, :render_order

    def initialize(name: nil)
      @name = name
      @visible = true
      @cast_shadow = false
      @receive_shadow = true
      @render_order = 0
      @children = []
      @parent = nil
      @local_revision = 0
      @cached_local_revision = -1
      @cached_parent_version = nil
      @cached_parent_identity = nil
      @world_version = 0
      @position = ObservedVec3.new(self)
      @rotation = ObservedQuat.new(self)
      @scale = ObservedVec3.new(self, Larb::Vec3.one)
      @local_matrix = Larb::Mat4.identity
      @world_matrix = Larb::Mat4.identity
    end

    def add(*nodes)
      nodes.flatten.each do |node|
        validate_child!(node)
        next if node.parent.equal?(self)

        node.parent&.remove(node)
        node.send(:parent=, self)
        children << node
      end
      self
    end

    def remove(node)
      return nil unless children.delete(node)

      node.send(:parent=, nil)
      node
    end

    def traverse(&block)
      return enum_for(:traverse) unless block

      block.call(self)
      children.each { |child| child.traverse(&block) }
      self
    end

    def find(target_name)
      traverse.find { |node| node.name == target_name }
    end

    def local_matrix
      return @local_matrix if @cached_local_revision == @local_revision

      @local_matrix = compose_local_matrix
      @cached_local_revision = @local_revision
      @local_matrix
    end

    def world_matrix
      world_matrix_with_version.first
    end

    def world_matrix_with_version
      parent_matrix, parent_version = parent&.world_matrix_with_version
      parent_identity = parent&.object_id
      stale = @cached_local_revision != @local_revision ||
              @cached_parent_version != parent_version ||
              @cached_parent_identity != parent_identity
      if stale
        local = local_matrix
        @world_matrix = parent_matrix ? parent_matrix * local : local
        @cached_parent_version = parent_version
        @cached_parent_identity = parent_identity
        @world_version += 1
      end
      [@world_matrix, @world_version]
    end

    def world_position
      world_matrix.extract_translation
    end

    def look_at(target, up: Larb::Vec3.up)
      target_value = target.respond_to?(:to_larb) ? target.to_larb : target
      eye = world_position
      raise ArgumentError, "look_at target must differ from position" if eye == target_value

      world_rotation = Larb::Mat4.look_at(eye, target_value, up).inverse.extract_rotation
      local_rotation = if parent
                         parent.world_matrix.extract_rotation.inverse * world_rotation
                       else
                         world_rotation
                       end
      rotation.set(local_rotation)
      self
    end

    def transform_dirty!
      @local_revision += 1
      self
    end

    protected

    def compose_local_matrix
      Larb::Mat4.translation(*position.to_a) *
        rotation.to_larb.to_mat4 *
        Larb::Mat4.scaling(*scale.to_a)
    end

    private

    def parent=(value)
      @parent = value
      @cached_parent_identity = nil
      @cached_parent_version = nil
    end

    def validate_child!(node)
      raise ArgumentError, "expected a Stagecraft::Node" unless node.is_a?(Node)
      raise ArgumentError, "a node cannot parent itself" if node.equal?(self)
      raise ArgumentError, "adding this node would create a cycle" if ancestor_of?(node)
    end

    def ancestor_of?(node)
      current = self
      while current
        return true if current.equal?(node)

        current = current.parent
      end
      false
    end
  end

  class MatrixNode < Node
    attr_reader :matrix

    def initialize(matrix, **)
      super(**)
      self.matrix = matrix
    end

    def matrix=(value)
      @matrix = value.is_a?(Larb::Mat4) ? value : Larb::Mat4.new(value.to_a)
      transform_dirty!
    end

    protected

    def compose_local_matrix
      matrix
    end
  end
end
