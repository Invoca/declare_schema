# frozen_string_literal: true

require 'declare_schema'
require 'rails'

module DeclareSchema
  class Railtie < Rails::Railtie
    ActiveSupport.on_load(:active_record) do
      require 'declare_schema/extensions/active_record/fields_declaration'
    end
  end
end
