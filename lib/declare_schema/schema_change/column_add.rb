# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class ColumnAdd < Base
      def initialize(table_name, column_name, column_type, **column_options)
        table_name.is_a?(String) || table_name.is_a?(Symbol) or raise ArgumentError, "must provide String|Symbol table_name; got #{table_name.inspect}"
        column_name.is_a?(String) || column_name.is_a?(Symbol) or raise ArgumentError, "must provide String|Symbol column_name; got #{column_name.inspect}"
        @table_name = table_name
        @column_name = column_name
        @column_type = column_type or raise ArgumentError, "must provide column_type"
        @column_options = column_options
      end

      def up_command
        "add_column #{[@table_name.to_sym.inspect,
                       @column_name.to_sym.inspect,
                       @column_type.to_sym.inspect,
                       *self.class.format_options(@column_options)].join(", ")}"
      end

      def down_command
        "remove_column #{@table_name.to_sym.inspect}, #{@column_name.to_sym.inspect}"
      end
    end
  end
end
