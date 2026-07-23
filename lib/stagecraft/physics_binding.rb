# frozen_string_literal: true

module Stagecraft
  class PhysicsBinding
    Entry = Data.define(:node, :body, :previous_position, :previous_rotation)

    def initialize
      @entries = []
    end

    def bind(node, body)
      raise ArgumentError, "physics binding requires a Stagecraft::Node" unless node.is_a?(Node)

      validate_body!(body)
      unbind(node)
      @entries << Entry.new(
        node:,
        body:,
        previous_position: vector(body.position),
        previous_rotation: quaternion(body.rotation)
      )
      self
    end

    def unbind(node)
      @entries.reject! { |entry| entry.node.equal?(node) }
      self
    end

    def sync!(alpha = 1.0)
      amount = Float(alpha).clamp(0.0, 1.0)
      @entries.map! do |entry|
        current_position = vector(entry.body.position)
        current_rotation = quaternion(entry.body.rotation)
        entry.node.position.set(entry.previous_position.lerp(current_position, amount))
        entry.node.rotation.set(entry.previous_rotation.slerp(current_rotation, amount))
        Entry.new(
          node: entry.node,
          body: entry.body,
          previous_position: current_position,
          previous_rotation: current_rotation
        )
      end
      self
    end

    private

    def validate_body!(body)
      return if body.respond_to?(:position) && body.respond_to?(:rotation)

      raise ArgumentError, "physics body must expose position and rotation"
    end

    def vector(value)
      Larb::Vec3.new(*value.to_a)
    end

    def quaternion(value)
      Larb::Quat.new(*value.to_a)
    end
  end
end
