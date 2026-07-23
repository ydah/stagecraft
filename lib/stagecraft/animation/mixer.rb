# frozen_string_literal: true

module Stagecraft
  module Animation
    class Mixer
      attr_reader :root, :actions

      def initialize(root)
        @root = root
        @actions = []
        @resolved_targets = {}
      end

      def play(clip, loop: :repeat, fade_in: 0.0)
        action = Action.new(clip, loop:, fade_in:)
        actions << action
        clip.tracks.each { |track| resolve_target(track) }
        action
      end

      def stop_all
        actions.each(&:stop)
        actions.clear
        self
      end

      def update(dt)
        samples = Hash.new { |hash, key| hash[key] = [] }
        actions.each do |action|
          next unless action.enabled

          action.advance(dt)
          action.clip.tracks.each do |track|
            target = resolve_target(track)
            next unless target

            samples[[target, track.target_path]] << [track.sample(action.time), action.weight]
          end
        end
        samples.each { |(target, path), values| apply_blend(target, path, values) }
        self
      end

      private

      def resolve_target(track)
        @resolved_targets[track.object_id] ||= case track.target
                                               when Node then track.target
                                               when String, Symbol then root.find(track.target.to_s)
                                               else track.target
                                               end
      end

      def apply_blend(target, path, samples)
        total = samples.sum(&:last)
        return if total.zero?

        value = if path == :rotation
                  blend_quaternions(samples, total)
                else
                  blend_vectors(samples, total)
                end
        case path
        when :translation then target.position.set(value)
        when :rotation then target.rotation.set(value)
        when :scale then target.scale.set(value)
        when :weights
          if target.respond_to?(:morph_weights=)
            target.morph_weights = value
          elsif target.respond_to?(:traverse)
            target.traverse do |node|
              node.morph_weights = value.dup if node.respond_to?(:morph_weights=)
            end
          end
        end
      end

      def blend_vectors(samples, total)
        size = samples.first.first.length
        Array.new(size) do |index|
          samples.sum { |value, weight| value[index] * weight } / total
        end
      end

      def blend_quaternions(samples, total)
        reference = samples.first.first
        components = Array.new(4, 0.0)
        samples.each do |value, weight|
          dot = 4.times.sum { |index| reference[index] * value[index] }
          sign = dot.negative? ? -1.0 : 1.0
          4.times { |index| components[index] += value[index] * weight * sign }
        end
        Larb::Quat.new(*components.map { |component| component / total }).normalize.to_a
      end
    end
  end
end
