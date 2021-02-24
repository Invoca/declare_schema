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

  @default_text_limit = 0xffff_ffff

  class << self
    attr_reader :default_text_limit

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

    def default_text_limit=(text_limit)
      text_limit.nil? or text_limit.is_a?(Integer) or raise ArgumentError, "text limit must be an integer or nil (got #{text_limit.inspect})"
      @default_text_limit = text_limit
    end
  end
end

require 'declare_schema/extensions/active_record/fields_declaration'
require 'declare_schema/field_declaration_dsl'
require 'declare_schema/model'
require 'declare_schema/model/field_spec'
require 'declare_schema/model/index_definition'
require 'declare_schema/model/foreign_key_definition'
require 'declare_schema/model/table_options_definition'

require 'declare_schema/railtie' if defined?(Rails)
