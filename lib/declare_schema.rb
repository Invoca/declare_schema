# frozen_string_literal: true

require 'invoca/utils'
require 'active_support'
require 'active_support/all'
require_relative 'declare_schema/version'

ActiveSupport::Dependencies.autoload_paths |= [__dir__]

module DeclareSchema
  # Empty class to represent the boolean type
  class Boolean; end
end

module DeclareSchema
  extend self

  PLAIN_TYPES = {
    :boolean       => DeclareSchema::Boolean,
    :date          => Date,
    :datetime      => ActiveSupport::TimeWithZone,
    :time          => Time,
    :integer       => Integer,
    :decimal       => BigDecimal,
    :float         => Float,
    :string        => String,
    :text          => String
  }.freeze

  @field_types   = PLAIN_TYPES.with_indifferent_access
  @never_wrap_types = Set.new([NilClass, DeclareSchema::Boolean, TrueClass, FalseClass])
  attr_reader :field_types

  def to_class(type)
    case type
    when Symbol, String
      type = type.to_sym
      field_types[type]
    else
      type # assume it's already a class
    end
  end

  def to_name(type)
    field_types.key(type) || ALIAS_TYPES[type]
  end

  def can_wrap?(type, val)
    col_type = type::COLUMN_TYPE
    return false if val.blank? && (col_type == :integer || col_type == :float || col_type == :decimal)
    klass = Object.instance_method(:class).bind(val).call # Make sure we get the *real* class
    init_method = type.instance_method(:initialize)
    [-1, 1].include?(init_method.arity) &&
      init_method.owner != Object.instance_method(:initialize).owner &&
      !@never_wrap_types.any? { |c| klass <= c }
  end

  def never_wrap(type)
    @never_wrap_types << type
  end

  def register_type(name, klass)
    field_types[name] = klass
  end

  def plain_type?(type_name)
    type_name.in?(PLAIN_TYPES)
  end
end

require 'declare_schema/extensions/active_record/fields_declaration'
require 'declare_schema/field_declaration_dsl'
require 'declare_schema/model'
require 'declare_schema/model/field_spec'
require 'declare_schema/model/index_spec'

require 'declare_schema/railtie' if defined?(Rails)


