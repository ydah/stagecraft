# frozen_string_literal: true

module Stagecraft
  class Attribute
    FORMAT_COMPONENTS = {
      float32: 1, float32x2: 2, float32x3: 3, float32x4: 4,
      uint16: 1, uint16x2: 2, uint16x4: 4, uint32: 1,
      unorm8x2: 2, unorm8x4: 4, uint8x2: 2, uint8x4: 4,
      sint8x2: 2, sint8x4: 4, snorm8x2: 2, snorm8x4: 4
    }.freeze

    attr_reader :data, :format, :count, :version

    def initialize(data:, format:, count:)
      @format = format.to_sym
      @count = Integer(count)
      @version = 0
      validate!
      self.data = data
    end

    def data=(value)
      raise ArgumentError, "attribute data must be a packed String" unless value.is_a?(String)

      @data = value.b.freeze
      @version += 1
    end

    def components
      FORMAT_COMPONENTS.fetch(format) { raise ArgumentError, "unsupported vertex format #{format.inspect}" }
    end

    private

    def validate!
      raise ArgumentError, "attribute count must be non-negative" if count.negative?

      components
    end
  end

  class IndexAttribute
    attr_reader :data, :format, :count, :version

    def initialize(data:, format:)
      @format = format.to_sym
      raise ArgumentError, "index format must be :uint16 or :uint32" unless %i[uint16 uint32].include?(@format)

      @version = 0
      self.data = data
    end

    def data=(value)
      raise ArgumentError, "index data must be a packed String" unless value.is_a?(String)

      @data = value.b.freeze
      width = format == :uint16 ? 2 : 4
      raise ArgumentError, "index data is not aligned to #{width} bytes" unless (@data.bytesize % width).zero?

      @count = @data.bytesize / width
      @version += 1
    end
  end
end
