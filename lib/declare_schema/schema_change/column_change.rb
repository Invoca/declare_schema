# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class ColumnChange < Base
      def initialize(table_name, column_name, old_type:, old_options:, new_type:, new_options:)
        @table_name = table_name
        @column_name = column_name
        @old_type = old_type
        @old_options = old_options
        @new_type = new_type
        @new_options = new_options
      end

      def up_command
        "change_column #{[@table_name.to_sym.inspect,
                          @column_name.to_sym.inspect,
                          @new_type.to_sym.inspect,
                          *self.class.format_options(@new_options)].join(", ")}"
      end

      def down_command
        "change_column #{[@table_name.to_sym.inspect,
                          @column_name.to_sym.inspect,
                          @old_type.to_sym.inspect,
                          *self.class.format_options(@old_options)].join(", ")}"
      end
    end
  end
end
