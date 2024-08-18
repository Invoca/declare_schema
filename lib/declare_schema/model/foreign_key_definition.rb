# frozen_string_literal: true

require_relative 'index_definition'

module DeclareSchema
  module Model
    class ForeignKeyDefinition
      include Comparable

      attr_reader :foreign_key_column, :constraint_name, :child_table_name, :parent_class_name, :dependent

      # Caller needs to pass either constraint_name or child_table_name, and
      # either parent_class_name or parent_table_name.
      def initialize(foreign_key_column, constraint_name: nil, child_table_name: nil, parent_class_name: nil, parent_table_name: nil, dependent: nil)
        @foreign_key_column = foreign_key_column&.to_s or raise ArgumentError "foreign key must not be empty: #{foreign_key_column.inspect}"
        @constraint_name = constraint_name&.to_s.presence || ::DeclareSchema::Model::IndexDefinition.default_index_name(child_table_name, [@foreign_key_column])
        @child_table_name = child_table_name&.to_s or raise ArgumentError, "child_table_name must not be nil"
        @parent_class_name =
          case parent_class_name
          when String, Symbol
            parent_class_name.to_s
          when Class
            @parent_class = parent_class_name
            @parent_class.name
          when nil
            @foreign_key_column.sub(/_id\z/, '').camelize
          end
        @parent_table_name = parent_table_name
        dependent.in?([nil, :delete]) or raise ArgumentError, "dependent: must be nil or :delete"
        @dependent = dependent
      end

      class << self
        # TODO: I think we might just be able to start using the AR built in moving forward
        def for_table(child_table_name, connection, dependent: nil)
          connection.foreign_keys(child_table_name).map do |fkc|
            new(
              fkc.column,
              constraint_name: fkc.name,
              child_table_name: fkc.from_table,
              parent_table_name: fkc.to_table,
              dependent: dependent || fkc.on_delete == :cascade ? :delete : nil
            )
          end
        end
      end

      def key
        @key ||= [@child_table_name, @foreign_key_column, @dependent].freeze
      end

      def <=>(rhs)
        key <=> rhs.key
      end

      alias eql? ==

      def equivalent?(rhs)
        self == rhs
      end

      # returns the parent class as a Class object
      # lazy loaded so that we don't require the parent class until we need it
      def parent_class
        @parent_class ||= @parent_class_name.constantize
      end

      def parent_table_name
        @parent_table_name ||= parent_class.table_name
      end

      def hash
        key.hash
      end
    end
  end
end
