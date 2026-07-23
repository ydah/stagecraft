# frozen_string_literal: true

module Stagecraft
  class Renderer
    class UniformPacker
      Field = Data.define(:name, :type, :offset, :size, :alignment, :value)
      Result = Data.define(:bytes, :fields, :struct_source, :textures)

      TYPE_INFO = {
        f32: [4, 4], u32: [4, 4],
        vec2f: [8, 8], vec3f: [16, 12], vec4f: [16, 16],
        mat4x4f: [16, 64]
      }.freeze

      def pack(uniforms = nil, struct_name: "MaterialUniforms", **keyword_uniforms)
        uniforms = (uniforms || {}).merge(keyword_uniforms)
        offset = 0
        fields = []
        textures = []
        uniforms.each do |name, value|
          if texture?(value)
            textures << [name.to_sym, value]
            next
          end

          type, normalized = infer(value)
          alignment, size = TYPE_INFO.fetch(type)
          offset = align(offset, alignment)
          fields << Field.new(name: name.to_sym, type:, offset:, size:, alignment:, value: normalized)
          offset += size
        end
        total_size = align(offset, [fields.map(&:alignment).max || 1, 16].max)
        bytes = "\0".b * total_size
        fields.each { |field| write(bytes, field) }
        Result.new(
          bytes: bytes.freeze,
          fields: fields.freeze,
          struct_source: declaration(struct_name, fields),
          textures: textures.freeze
        )
      end

      private

      def infer(value)
        case value
        when Integer then [:u32, value]
        when Numeric then [:f32, value.to_f]
        when Color then [:vec4f, value.to_a]
        when Larb::Vec2 then [:vec2f, value.to_a]
        when Larb::Vec3 then [:vec3f, value.to_a]
        when Larb::Vec4, Larb::Quat then [:vec4f, value.to_a]
        when Larb::Mat4 then [:mat4x4f, value.to_a]
        when Array then infer_array(value)
        else
          if value.respond_to?(:to_larb)
            infer(value.to_larb)
          else
            raise ArgumentError, "unsupported uniform #{value.class}"
          end
        end
      end

      def infer_array(value)
        type = { 2 => :vec2f, 3 => :vec3f, 4 => :vec4f, 16 => :mat4x4f }[value.length]
        raise ArgumentError, "uniform arrays must contain 2, 3, 4, or 16 numbers" unless type
        raise ArgumentError, "uniform arrays must be numeric" unless value.all? { |item| item.is_a?(Numeric) }

        [type, value.map(&:to_f)]
      end

      def texture?(value)
        value.is_a?(Textures::Texture)
      end

      def align(value, alignment)
        ((value + alignment - 1) / alignment) * alignment
      end

      def write(bytes, field)
        packed = field.type == :u32 ? [field.value].pack("L<") : Array(field.value).pack("e*")
        bytes[field.offset, packed.bytesize] = packed
      end

      def declaration(name, fields)
        body = fields.map { |field| "  #{field.name}: #{field.type}," }.join("\n")
        "struct #{name} {\n#{body}\n};"
      end
    end
  end
end
