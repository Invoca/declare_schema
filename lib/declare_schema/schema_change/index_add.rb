# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class IndexAdd < Base
      def initialize(table_name, column_names, name:, unique:, where: nil, length: nil)
        @table_name = table_name
        @column_names = column_names
        @name = name
        @unique = unique
        @where = where.presence
        @length = length
      end

      def up_command
        options = {
          name: @name.to_sym,
        }
        options[:unique] = true if @unique
        options[:where] = @where if @where
        options[:length] = @length if @length

        "add_index #{[@table_name.to_sym.inspect,
                      @column_names.map(&:to_sym).inspect,
                      *self.class.format_options(options)].join(', ')}"
      end

      def down_command
        "remove_index #{@table_name.to_sym.inspect}, name: #{@name.to_sym.inspect}"
      end
    end
  end
end
