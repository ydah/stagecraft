# frozen_string_literal: true

module Stagecraft
  module Materials
    class Unlit < Base
      def initialize(color: Color.new(1.0), map: nil, **)
        super(**)
        self.color = color
        self.map = map
      end

      versioned_attribute :color, coerce: Color.method(:coerce)
      versioned_attribute :map
    end

    UnlitMaterial = Unlit
  end
end
