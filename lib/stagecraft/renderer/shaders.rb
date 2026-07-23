# frozen_string_literal: true

module Stagecraft
  class Renderer
    module Shaders
      ROOT = File.expand_path("shaders", __dir__)
      DIRECTIVE = %r{\A\s*//#(if|else|endif|include)\b(?:\s+["']?([^"'\s]+)["']?)?\s*\z}

      module_function

      def compose(name, defines: Set.new)
        @cache ||= {}
        key = [name.to_s, defines.to_a.map(&:to_s).sort].freeze
        @cache[key] ||= process(read(name), defines.map(&:to_s).to_set, [name.to_s]).freeze
      end

      def clear_cache
        @cache = {}
      end

      def read(name)
        path = File.expand_path(name.to_s, ROOT)
        raise ArgumentError, "shader path escapes shader root" unless path.start_with?("#{ROOT}/")
        raise ArgumentError, "shader not found: #{name}" unless File.file?(path)

        File.read(path)
      end

      def process(source, defines, stack)
        enabled = [true]
        output = []
        source.each_line do |line|
          match = DIRECTIVE.match(line)
          unless match
            output << line if enabled.last
            next
          end

          operation, argument = match.captures
          case operation
          when "if"
            enabled << (enabled.last && defines.include?(argument))
          when "else"
            parent_enabled = enabled[-2]
            enabled[-1] = parent_enabled && !enabled[-1]
          when "endif"
            raise Error, "unmatched shader endif in #{stack.last}" if enabled.length == 1

            enabled.pop
          when "include"
            next unless enabled.last
            raise Error, "shader include cycle: #{[*stack, argument].join(" -> ")}" if stack.include?(argument)

            output << process(read(argument), defines, [*stack, argument])
          end
        end
        raise Error, "unterminated shader condition in #{stack.last}" unless enabled.length == 1

        output.join
      end
      private_class_method :process
    end
  end
end
