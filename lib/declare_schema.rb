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

  @default_charset               = "utf8mb4"
  @default_collation             = "utf8mb4_bin"
  @default_text_limit            = 0xffff_ffff
  @default_string_limit          = nil
  @default_null                  = false
  @default_generate_foreign_keys = true
  @default_generate_indexing     = true

  class << self
    attr_reader :default_charset, :default_collation, :default_text_limit, :default_string_limit, :default_null,
                :default_generate_foreign_keys, :default_generate_indexing

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

    def default_charset=(charset)
      charset.is_a?(String) or raise ArgumentError, "charset must be a string (got #{charset.inspect})"
      @default_charset = charset
    end

    def default_collation=(collation)
      collation.is_a?(String) or raise ArgumentError, "collation must be a string (got #{collation.inspect})"
      @default_collation = collation
    end

    def default_text_limit=(text_limit)
      text_limit.nil? or text_limit.is_a?(Integer) or raise ArgumentError, "text limit must be an integer or nil (got #{text_limit.inspect})"
      @default_text_limit = text_limit
    end

    def default_string_limit=(string_limit)
      string_limit.nil? or string_limit.is_a?(Integer) or raise ArgumentError, "string limit must be an integer or nil (got #{string_limit.inspect})"
      @default_string_limit = string_limit
    end

    def default_null=(null)
      null.in?([true, false, nil]) or raise ArgumentError, "null must be either true, false, or nil (got #{null.inspect})"
      @default_null = null
    end

    def default_generate_foreign_keys=(generate_foreign_keys)
      generate_foreign_keys.in?([true, false]) or raise ArgumentError, "generate_foreign_keys must be either true or false (got #{generate_foreign_keys.inspect})"
      @default_generate_foreign_keys = generate_foreign_keys
    end

    def default_generate_indexing=(generate_indexing)
      [true, false].include?(generate_indexing) or raise ArgumentError, "generate_indexing must be either true or false (got #{generate_indexing.inspect})"
      @default_generate_indexing = generate_indexing
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
