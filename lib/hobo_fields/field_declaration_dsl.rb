require 'active_support/proxy_object'
require 'hobo_fields/types/enum_string'

module HoboFields

  class FieldDeclarationDsl < ActiveSupport::ProxyObject

    include Types::EnumString::DeclarationHelper

    def initialize(model, options = {})
      @model = model
      @options = options
    end

    attr_reader :model


    def timestamps
      field(:created_at, :datetime, :null => true)
      field(:updated_at, :datetime, :null => true)
    end

    def optimistic_lock
      field(:lock_version, :integer, :default => 1, :null => false)
    end

    def field(name, type, *args)
      options = args.extract_options!
      @model.declare_field(name, type, *(args + [@options.merge(options)]))
    end


    def method_missing(name, *args)
      field(name, args.first, *args[1..-1])
    end

  end

end
