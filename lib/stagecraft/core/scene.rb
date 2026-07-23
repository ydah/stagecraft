# frozen_string_literal: true

module Stagecraft
  class Scene < Node
    attr_reader :background

    def background=(value)
      @background = value.nil? ? nil : Color.coerce(value)
    end
  end
end
