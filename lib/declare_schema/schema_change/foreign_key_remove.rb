# frozen_string_literal: true

require_relative 'foreign_key_add'

module DeclareSchema
  module SchemaChange
    class ForeignKeyRemove < ForeignKeyAdd
      alias index_add_up_command up_command
      alias index_add_down_command down_command

      def up_command
        index_add_down_command
      end

      def down_command
        index_add_up_command
      end
    end
  end
end
