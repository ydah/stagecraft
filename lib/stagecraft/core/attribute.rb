# frozen_string_literal: true

module Stagecraft
  class Attribute
    FORMAT_COMPONENTS = {
      float32: 1, float32x2: 2, float32x3: 3, float32x4: 4,
      uint16: 1, uint16x2: 2, uint16x4: 4,
      sint16x2: 2, sint16x4: 4, snorm16x2: 2, snorm16x4: 4,
      unorm16x2: 2, unorm16x4: 4,
      uint32: 1, uint32x2: 2, uint32x3: 3, uint32x4: 4,
      unorm8x2: 2, unorm8x4: 4, uint8x2: 2, uint8x4: 4,
      sint8x2: 2, sint8x4: 4, snorm8x2: 2, snorm8x4: 4
    }.freeze
    FORMAT_WIDTHS = {
      float32: 4, uint32: 4, uint16: 2,
      uint8: 1, unorm8: 1, sint8: 1, snorm8: 1,
      sint16: 2, snorm16: 2, unorm16: 2
    }.freeze

    attr_reader :data, :format, :count, :version

    def initialize(data:, format:, count:, &on_change)
      @format = format.to_sym
      @count = Integer(count)
      @version = 0
      @on_change = on_change
      @initialized = false
      validate!
      self.data = data
      @initialized = true
    end

    def data=(value)
      raise ArgumentError, "attribute data must be a packed String" unless value.is_a?(String)

      @data = value.b.freeze
      expected_size = count * byte_stride
      unless @data.bytesize == expected_size
        raise ArgumentError, "attribute data must contain #{expected_size} bytes, got #{@data.bytesize}"
      end
      @version += 1
      @on_change&.call if @initialized
    end

    def components
      FORMAT_COMPONENTS.fetch(format) { raise ArgumentError, "unsupported vertex format #{format.inspect}" }
    end

    def byte_stride
      prefix = FORMAT_WIDTHS.keys.find { |candidate| format.to_s.start_with?(candidate.to_s) }
      FORMAT_WIDTHS.fetch(prefix) * components
    end

    private

    def validate!
      raise ArgumentError, "attribute count must be non-negative" if count.negative?

      components
    end
  end

  class IndexAttribute
    attr_reader :data, :format, :count, :version

    def initialize(data:, format:, &on_change)
      @format = format.to_sym
      raise ArgumentError, "index format must be :uint16 or :uint32" unless %i[uint16 uint32].include?(@format)

      @version = 0
      @on_change = on_change
      @initialized = false
      self.data = data
      @initialized = true
    end

    def data=(value)
      raise ArgumentError, "index data must be a packed String" unless value.is_a?(String)

      @data = value.b.freeze
      width = format == :uint16 ? 2 : 4
      raise ArgumentError, "index data is not aligned to #{width} bytes" unless (@data.bytesize % width).zero?

      @count = @data.bytesize / width
      @version += 1
      @on_change&.call if @initialized
    end
  end
end
