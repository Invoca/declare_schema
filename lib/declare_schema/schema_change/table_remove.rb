# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableRemove < Base
      def initialize(table_name, add_table_back)
        @table_name = table_name
        @add_table_back = add_table_back
      end

      def up_command
        "drop_table #{@table_name.to_sym.inspect}"
      end

      def down_command
        @add_table_back
      end
    end
  end
end
