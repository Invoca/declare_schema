# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class IndexAdd < Base
      def initialize(table_name, column_names, name:, unique:)
        @table_name = table_name
        @column_names = column_names
        @name = name
        @unique = unique
      end

      def up_command
        "create_index #{[@table_name.to_sym.inspect,
                         @column_names.map(&:to_sym).inspect,
                         "name: #{@name.inspect}",
                         "unique: #{@unique.inspect}"].join(", ")}"
      end

      def down_command
        "remove_index #{@table_name.to_sym.inspect}, name: #{@name.inspect}"
      end
    end
  end
end
