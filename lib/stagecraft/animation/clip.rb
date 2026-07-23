# frozen_string_literal: true

module Stagecraft
  module Animation
    class Clip
      attr_reader :name, :tracks, :duration

      def initialize(name: nil, tracks:, duration: nil)
        @name = name
        @tracks = tracks.freeze
        @duration = duration ? Float(duration) : (@tracks.map(&:duration).max || 0.0)
      end
    end
  end
end
