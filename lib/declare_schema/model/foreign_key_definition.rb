# frozen_string_literal: true

require_relative 'index_definition'

module DeclareSchema
  module Model
    class ForeignKeyDefinition
      include Comparable

      attr_reader :foreign_key_column, :constraint_name, :child_table_name, :parent_table_name, :dependent

      # Caller needs to pass either constraint_name or child_table. The child_table is remembered, but it is not part of the key;
      # it is just used to compute the default constraint_name if no constraint_name is given.
      def initialize(foreign_key_column, constraint_name: nil, child_table: nil, parent_table: nil, class_name: nil, dependent: nil)
        @foreign_key_column = foreign_key_column&.to_s or raise ArgumentError "foreign key must not be empty: #{foreign_key_column.inspect}"
        @constraint_name = constraint_name&.to_s.presence || ::DeclareSchema::Model::IndexDefinition.default_index_name(child_table, [@foreign_key_column])
        @child_table_name = child_table&.to_s or raise ArgumentError, "child_table must not be nil"
        @parent_table_name = parent_table&.to_s || infer_parent_table_name_from_class(class_name) || infer_parent_table_name_from_foreign_key_column(@foreign_key_column)
        dependent.in?([nil, :delete]) or raise ArgumentError, "dependent: must be nil or :delete"
        @dependent = dependent
      end

      class << self
        def for_table(table_name, connection, dependent: nil)
          show_create_table = connection.select_rows("show create table #{connection.quote_table_name(table_name)}").first.last
          constraints = show_create_table.split("\n").map { |line| line.strip if line['CONSTRAINT'] }.compact

          constraints.map do |fkc|
            constraint_name, foreign_key_column, parent_table = fkc.match(/CONSTRAINT `([^`]*)` FOREIGN KEY \(`([^`]*)`\) REFERENCES `([^`]*)`/).captures
            dependent_value = :delete if dependent || fkc['ON DELETE CASCADE']

            new(foreign_key_column, constraint_name: constraint_name, child_table: table_name, parent_table: parent_table, dependent: dependent_value)
          end
        end
      end

      def key
        @key ||= [@parent_table_name, @foreign_key_column, @dependent].freeze
      end

      def <=>(rhs)
        key <=> rhs.key
      end

      alias eql? ==

      def equivalent?(rhs)
        self == rhs
      end

      private

      # returns the parent class as a Class object
      # or nil if no @class_name option given
      def parent_class(class_name)
        if class_name
          if class_name.is_a?(Class)
            class_name
          else
            class_name.to_s.constantize
          end
        end
      end

      def infer_parent_table_name_from_class(class_name)
        parent_class(class_name)&.try(:table_name)
      end

      def infer_parent_table_name_from_foreign_key_column(foreign_key_column)
        foreign_key_column.sub(/_id\z/, '').camelize.constantize.table_name
      end

      def hash
        key.hash
      end
    end
  end
end
