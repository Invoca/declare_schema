# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableChange < Base

      # @param [String] table_name  The name of the table being changed
      # @param [Hash]   old_options The old/existing table option definitions
      # @param [Hash]   new_options The new/existing table option definitions
      def initialize(table_name, old_options, new_options)
        old_options.is_a?(Hash) or raise ArgumentError, "old_options must be a Hash but is: #{old_options.inspect}"
        new_options.is_a?(Hash) or raise ArgumentError, "new_options must be a Hash but is: #{new_options.inspect}"

        @table_name  = table_name
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
