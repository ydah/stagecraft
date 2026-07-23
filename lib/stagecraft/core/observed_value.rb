# frozen_string_literal: true

module Stagecraft
  class ObservedVec3
    COMPONENTS = %i[x y z].freeze

    def initialize(owner, value = Larb::Vec3.new)
      @owner = owner
      @value = coerce(value)
    end

    COMPONENTS.each_with_index do |component, index|
      define_method(component) { @value.public_send(component) }
      define_method(:"#{component}=") do |new_value|
        return new_value if @value.public_send(component) == new_value.to_f

        @value.public_send(:"#{component}=", new_value.to_f)
        changed!
        new_value
      end
    end

    def set(x, y = nil, z = nil)
      values = y.nil? && z.nil? ? vector_components(x) : [x, y, z]
      return self if to_a == values.map(&:to_f)

      @value = Larb::Vec3.new(*values)
      changed!
      self
    end

    def []=(index, value)
      component = COMPONENTS.fetch(index)
      public_send(:"#{component}=", value)
    end

    def [](index)
      @value[index]
    end

    def normalize!
      set(@value.normalize)
    end

    def to_larb
      Larb::Vec3.new(*to_a)
    end

    def to_a
      @value.to_a
    end

    def ==(other)
      other.respond_to?(:to_a) && to_a == other.to_a
    end

    def inspect
      "#{self.class.name}[#{to_a.join(", ")}]"
    end

    def method_missing(name, *arguments, **keywords, &block)
      return super unless @value.respond_to?(name)

      @value.public_send(name, *unwrap_arguments(*arguments), **keywords, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @value.respond_to?(name, include_private) || super
    end

    private

    def changed!
      @owner.transform_dirty!
    end

    def coerce(value)
      Larb::Vec3.new(*vector_components(value))
    end

    def vector_components(value)
      return value.to_a if value.respond_to?(:to_a)

      Array(value)
    end

    def unwrap_arguments(*arguments)
      arguments.map { |argument| argument.respond_to?(:to_larb) ? argument.to_larb : argument }
    end
  end

  class ObservedQuat
    COMPONENTS = %i[x y z w].freeze

    def initialize(owner, value = Larb::Quat.new)
      @owner = owner
      @value = coerce(value)
    end

    COMPONENTS.each_with_index do |component, index|
      define_method(component) { @value.public_send(component) }
      define_method(:"#{component}=") do |new_value|
        return new_value if @value[index] == new_value.to_f

        @value.public_send(:"#{component}=", new_value.to_f)
        changed!
        new_value
      end
    end

    def set(x, y = nil, z = nil, w = nil)
      values = y.nil? && z.nil? && w.nil? ? x.to_a : [x, y, z, w]
      next_value = Larb::Quat.new(*values).normalize
      return self if @value == next_value

      @value = next_value
      changed!
      self
    end

    def rotate_x!(angle)
      rotate_axis!(Larb::Vec3.right, angle)
    end

    def rotate_y!(angle)
      rotate_axis!(Larb::Vec3.up, angle)
    end

    def rotate_z!(angle)
      rotate_axis!(Larb::Vec3.back, angle)
    end

    def slerp!(target, amount)
      set(@value.slerp(coerce(target), amount))
    end

    def normalize!
      set(@value.normalize)
    end

    def to_larb
      Larb::Quat.new(*to_a)
    end

    def to_a
      @value.to_a
    end

    def ==(other)
      other.respond_to?(:to_a) && to_a == other.to_a
    end

    def inspect
      "#{self.class.name}[#{to_a.join(", ")}]"
    end

    def method_missing(name, *arguments, **keywords, &block)
      return super unless @value.respond_to?(name)

      values = arguments.map { |argument| argument.respond_to?(:to_larb) ? argument.to_larb : argument }
      @value.public_send(name, *values, **keywords, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @value.respond_to?(name, include_private) || super
    end

    private

    def rotate_axis!(axis, angle)
      set(@value * Larb::Quat.from_axis_angle(axis, angle.to_f))
    end

    def changed!
      @owner.transform_dirty!
    end

    def coerce(value)
      value.is_a?(Larb::Quat) ? value : Larb::Quat.new(*value.to_a)
    end
  end
end
