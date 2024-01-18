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
        def for_table(child_table_name, connection, dependent: nil)
          show_create_table = connection.select_rows("show create table #{connection.quote_table_name(child_table_name)}").first.last
          constraints = show_create_table.split("\n").map { |line| line.strip if line['CONSTRAINT'] }.compact

          constraints.map do |fkc|
            constraint_name, foreign_key_column, parent_table_name = fkc.match(/CONSTRAINT `([^`]*)` FOREIGN KEY \(`([^`]*)`\) REFERENCES `([^`]*)`/).captures
            dependent_value = :delete if dependent || fkc['ON DELETE CASCADE']

            new(foreign_key_column,
                constraint_name: constraint_name,
                child_table_name: child_table_name,
                parent_table_name: parent_table_name,
                dependent: dependent_value)
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
