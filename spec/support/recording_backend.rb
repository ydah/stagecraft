# frozen_string_literal: true

module SpecSupport
  class RecordingBackend
    attr_reader :commands

    def initialize
      @commands = []
    end

    def begin_frame(camera:)
      commands << [:begin_frame, camera]
    end

    def draw(**payload)
      commands << [:draw, payload]
    end

    def end_frame
      commands << [:end_frame]
    end
  end
end
