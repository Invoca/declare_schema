# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class ForeignKeyAdd < Base
      def initialize(table_name, parent_table_name, column_name:, name:)
        @table_name = table_name
        @parent_table_name = parent_table_name
        @column_name = column_name
        @name = name
      end

      def up_command
        "add_foreign_key #{@table_name.to_sym.inspect}, #{@parent_table_name.to_sym.inspect}, " +
          "column: #{@column_name.to_sym.inspect}, name: #{@name.to_sym.inspect}"
      end

      def down_command
        "remove_foreign_key #{@table_name.to_sym.inspect}, name: #{@name.to_sym.inspect}"
      end
    end
  end
end
