# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableCreate < Base
      def initialize(table_name, create_table)
        @table_name = table_name
        @create_table = create_table
      end

      def up_command
        @create_table
      end

      def down_command
        "drop_table #{@table_name.to_sym.inspect}"
      end
    end
  end
end
