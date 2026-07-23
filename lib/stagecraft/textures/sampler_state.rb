# frozen_string_literal: true

module Stagecraft
  module Textures
    SamplerState = Data.define(
      :wrap_u, :wrap_v, :wrap_w, :mag_filter, :min_filter, :mipmap_filter,
      :lod_min, :lod_max, :compare, :max_anisotropy
    ) do
      FILTERS = %i[nearest linear].freeze

      def initialize(wrap_u: :repeat, wrap_v: :repeat, wrap_w: :repeat,
                     mag_filter: :linear, min_filter: :linear, mipmap_filter: :linear,
                     lod_min: 0.0, lod_max: 32.0, compare: nil, max_anisotropy: 1)
        super(
          wrap_u: normalize_wrap(wrap_u),
          wrap_v: normalize_wrap(wrap_v),
          wrap_w: normalize_wrap(wrap_w),
          mag_filter: mag_filter.to_sym,
          min_filter: min_filter.to_sym,
          mipmap_filter: mipmap_filter.to_sym,
          lod_min: Float(lod_min),
          lod_max: Float(lod_max),
          compare: compare&.to_sym,
          max_anisotropy: Integer(max_anisotropy)
        )
        validate!
      end

      private

      def normalize_wrap(value)
        {
          repeat: :repeat,
          mirrored_repeat: :mirror_repeat,
          mirror_repeat: :mirror_repeat,
          clamp_to_edge: :clamp_to_edge
        }.fetch(value.to_sym)
      end

      def validate!
        raise ArgumentError, "mag_filter must be :nearest or :linear" unless FILTERS.include?(mag_filter)
        raise ArgumentError, "min_filter must be :nearest or :linear" unless FILTERS.include?(min_filter)
        unless FILTERS.include?(mipmap_filter)
          raise ArgumentError, "mipmap_filter must be :nearest or :linear"
        end
        raise ArgumentError, "lod_min must be non-negative" if lod_min.negative?
        raise ArgumentError, "lod_max must be at least lod_min" if lod_max < lod_min
        unless max_anisotropy.between?(1, 16)
          raise ArgumentError, "max_anisotropy must be between 1 and 16"
        end
        return if max_anisotropy == 1 ||
                  [mag_filter, min_filter, mipmap_filter].all? { |filter| filter == :linear }

        raise ArgumentError, "anisotropic filtering requires linear filters"
      end
    end
  end
end
