# frozen_string_literal: true

class Module

  private

  # Creates a class attribute reader that will delegate to the superclass
  # if not defined on self. Default values can be a Proc object that takes the class as a parameter.
  def inheriting_cattr_reader(*names)
    receiver =
      if self.class == Module
        self
      else
        singleton_class
      end

    names_with_defaults = (names.pop if names.last.is_a?(Hash)) || {}

    (names + names_with_defaults.keys).each do |name|
      ivar_name = "@#{name}"
      block = names_with_defaults[name]

      receiver.send(:define_method, name) do
        if instance_variable_defined? ivar_name
          instance_variable_get(ivar_name)
        else
          superclass.respond_to?(name) && superclass.send(name) ||
            block && begin
              result = block.is_a?(Proc) ? block.call(self) : block
              instance_variable_set(ivar_name, result) if result
            end
        end
      end
    end
  end
end
