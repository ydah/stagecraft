# frozen_string_literal: true

module Stagecraft
  module Lights
    ShadowConfig = Data.define(:map_size, :near, :far, :extent) do
      def initialize(map_size: 2_048, near: 0.1, far: 100.0, extent: 20.0)
        super(
          map_size: Integer(map_size),
          near: Float(near),
          far: Float(far),
          extent: Float(extent)
        )
        raise ArgumentError, "shadow map_size must be positive" unless self.map_size.positive?
        raise ArgumentError, "shadow far must exceed near" unless self.far > self.near
        raise ArgumentError, "shadow extent must be positive" unless self.extent.positive?
      end
    end

    class Directional < Light
      attr_accessor :shadow

      def initialize(cast_shadow: false, shadow: ShadowConfig.new, **)
        super(**)
        self.cast_shadow = cast_shadow
        @shadow = shadow
      end
    end

    DirectionalLight = Directional
  end
end
