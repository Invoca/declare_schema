# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableChange < Base
      def initialize(table_name, old_options, new_options)
        @table_name = table_name
        @old_options = old_options
        @new_options = new_options
      end

      def up_command
        alter_table(@table_name, @new_options)
      end

      def down_command
        alter_table(@table_name, @old_options)
      end

      private

      TABLE_OPTIONS_TO_SQL_MAPPINGS = {
        charset:   'CHARACTER SET',
        collation: 'COLLATE'
      }.freeze

      def alter_table(table_name, options)
        sql_options = options.map { |key, value| [TABLE_OPTIONS_TO_SQL_MAPPINGS[key], value] }
        statement = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} #{sql_options.join(' ')}"
        "execute #{statement.inspect}"
      end
    end
  end
end
