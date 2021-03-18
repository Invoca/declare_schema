# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class ColumnRename < Base
      def initialize(table_name, old_name, new_name)
        @table_name = table_name
        @old_name = old_name
        @new_name = new_name
      end

      def up_command
        "rename_column #{@table_name.to_sym.inspect}, #{@old_name.to_sym.inspect}, #{@new_name.to_sym.inspect}"
      end

      def down_command
        "rename_column #{@table_name.to_sym.inspect}, #{@new_name.to_sym.inspect}, #{@old_name.to_sym.inspect}"
      end
    end
  end
end
