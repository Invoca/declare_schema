# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class ColumnAdd < Base
      def initialize(table_name, column_name, column_type, **column_options)
        @table_name = table_name or raise ArgumentError, "must provide table_name"
        @column_name = column_name or raise ArgumentError, "must provide column_name"
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
