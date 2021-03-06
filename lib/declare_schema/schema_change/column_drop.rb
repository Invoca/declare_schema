# frozen_string_literal: true

require_relative 'column_add'

module DeclareSchema
  module SchemaChange
    class ColumnDrop < ColumnAdd
      alias column_add_up_command up_command
      alias column_add_down_command down_command

      def up_command
        column_add_down_command
      end

      def down_command
        column_add_up_command
      end
    end
  end
end
