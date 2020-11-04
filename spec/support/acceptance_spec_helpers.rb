# frozen_string_literal: true

module AcceptanceSpecHelpers
  def generate_model(model_name, *fields)
    Rails::Generators.invoke('declare_schema:model', [model_name, *fields])
  end

  def generate_migrations(*flags)
    Rails::Generators.invoke('declare_schema:migration', flags)
  end
end
