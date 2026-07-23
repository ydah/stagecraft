# frozen_string_literal: true

module Stagecraft
  module Controls
    class Orbit
      attr_reader :camera, :target
      attr_accessor :enabled, :rotate_speed, :zoom_speed, :pan_speed, :damping,
                    :min_distance, :max_distance, :min_polar_angle, :max_polar_angle

      def initialize(camera, window = nil, target: Larb::Vec3.new)
        @camera = camera
        @target = vector(target)
        @enabled = true
        @rotate_speed = 0.005
        @zoom_speed = 0.15
        @pan_speed = 0.002
        @damping = 12.0
        @min_distance = 0.01
        @max_distance = Float::INFINITY
        @min_polar_angle = 1e-4
        @max_polar_angle = Math::PI - 1e-4
        @azimuth_delta = 0.0
        @polar_delta = 0.0
        @zoom_delta = 0.0
        @pan_delta = Larb::Vec3.new
        @dragging = false
        sync_spherical
        attach(window) if window
      end

      def target=(value)
        @target = vector(value)
        sync_spherical
      end

      def rotate(delta_x, delta_y)
        return self unless enabled

        @azimuth_delta -= Float(delta_x) * rotate_speed
        @polar_delta -= Float(delta_y) * rotate_speed
        self
      end

      def zoom(delta)
        return self unless enabled

        @zoom_delta += Float(delta) * zoom_speed
        self
      end

      def pan(delta_x, delta_y)
        return self unless enabled

        rotation = camera.world_matrix.extract_rotation
        right = rotation * Larb::Vec3.right
        up = rotation * Larb::Vec3.up
        scale = @radius * pan_speed
        @pan_delta = @pan_delta + (right * (-Float(delta_x) * scale)) + (up * (Float(delta_y) * scale))
        self
      end

      def update(dt = 1.0 / 60.0)
        return self unless enabled

        response = 1.0 - Math.exp(-damping * [Float(dt), 0.0].max)
        @azimuth += @azimuth_delta * response
        @polar = (@polar + (@polar_delta * response)).clamp(min_polar_angle, max_polar_angle)
        @radius = (@radius * Math.exp(@zoom_delta * response)).clamp(min_distance, max_distance)
        @target = @target + (@pan_delta * response)
        decay = 1.0 - response
        @azimuth_delta *= decay
        @polar_delta *= decay
        @zoom_delta *= decay
        @pan_delta = @pan_delta * decay
        update_camera
        self
      end

      private

      def attach(window)
        window.on_pointer_button do |button, pressed, _x, _y|
          @dragging = pressed if left_button?(button)
        end
        window.on_pointer_move do |_x, _y, relative_x, relative_y|
          rotate(relative_x, relative_y) if @dragging
        end
        window.on_scroll { |_x, y| zoom(-y) }
      end

      def left_button?(button)
        [1, :left, (defined?(GLFW::GLFW_MOUSE_BUTTON_LEFT) && GLFW::GLFW_MOUSE_BUTTON_LEFT)].include?(button)
      end

      def sync_spherical
        offset = camera.world_position - target
        @radius = [offset.length, min_distance].max
        @azimuth = Math.atan2(offset.x, offset.z)
        @polar = Math.acos((offset.y / @radius).clamp(-1.0, 1.0))
      end

      def update_camera
        sin_polar = Math.sin(@polar)
        camera.position.set(
          target.x + (@radius * sin_polar * Math.sin(@azimuth)),
          target.y + (@radius * Math.cos(@polar)),
          target.z + (@radius * sin_polar * Math.cos(@azimuth))
        )
        camera.look_at(target)
      end

      def vector(value)
        value.is_a?(Larb::Vec3) ? value : Larb::Vec3.new(*value.to_a)
      end
    end

    OrbitControls = Orbit
  end
end
