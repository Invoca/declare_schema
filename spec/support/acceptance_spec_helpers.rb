# frozen_string_literal: true

module AcceptanceSpecHelpers
  def generate_model(model_name, *fields)
    Rails::Generators.invoke('declare_schema:model', [model_name, *fields])
  end
end
