# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableRename < Base
      def initialize(old_name, new_name)
        @old_name = old_name
        @new_name = new_name
      end

      def up_command
        "rename_table :#{@old_name}, :#{@new_name}"
      end

      def down_command
        "rename_table :#{@new_name}, :#{@old_name}"
      end
    end
  end
end
