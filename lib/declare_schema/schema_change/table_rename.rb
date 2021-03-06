# frozen_string_literal: true

module DeclareSchema
  module SchemaChange
    class TableRename
      def initialize(old_name, new_name)
        @old_name = old_name
        @new_name = new_name
      end

      def up
        "rename_table :#{@old_name}, :#{@new_name}"
      end

      def down
        "rename_table :#{@new_name}, :#{@old_name}"
      end
    end
  end
end
