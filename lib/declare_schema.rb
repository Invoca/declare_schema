# frozen_string_literal: true

require 'active_support'
require 'active_support/all'
require_relative 'declare_schema/version'

ActiveSupport::Dependencies.autoload_paths |= [__dir__]

module DeclareSchema
  class Boolean; end

  PLAIN_TYPES = {
    boolean:  Boolean,
    date:     Date,
    datetime: ActiveSupport::TimeWithZone,
    time:     Time,
    integer:  Integer,
    decimal:  BigDecimal,
    float:    Float,
    string:   String,
    text:     String
  }.freeze

  class << self
    def to_class(type)
      case type
      when Class
        type
      when Symbol, String
        PLAIN_TYPES[type.to_sym]
      else
        raise ArgumentError, "expected Class or Symbol or String: got #{type.inspect}"
      end
    end
  end
end

require 'declare_schema/extensions/active_record/fields_declaration'
require 'declare_schema/field_declaration_dsl'
require 'declare_schema/model'
require 'declare_schema/model/field_spec'
require 'declare_schema/model/index_spec'

require 'declare_schema/railtie' if defined?(Rails)
