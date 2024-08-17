# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class PrimaryKeyChange < Base
      def initialize(table_name, old_column_names, new_column_names) # rubocop:disable Lint/MissingSuper
        @table_name = table_name
        @old_column_names = old_column_names.presence
        @new_column_names = new_column_names.presence
      end

      def up_command
        alter_primary_key(@old_column_names, @new_column_names)
      end

      def down_command
        alter_primary_key(@new_column_names, @old_column_names)
      end

      private

      def alter_primary_key(old_col_names, new_col_names)
        if current_adapter == 'postgresql'
          [].tap do |commands|
            if old_col_names
              drop_command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(@table_name)} DROP CONSTRAINT #{@table_name}_pkey;"
              commands << "execute #{drop_command.inspect}"
            end
            if new_col_names
              add_command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(@table_name)} ADD PRIMARY KEY (#{new_col_names.join(', ')});"
              commands << "execute #{add_command.inspect}"
            end
          end.join("\n")
        else
          drop_command = "DROP PRIMARY KEY" if old_col_names
          add_command = "ADD PRIMARY KEY (#{new_col_names.join(', ')})" if new_col_names
          commands = [drop_command, add_command].compact.join(', ')
          statement = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(@table_name)} #{commands}"
          "execute #{statement.inspect}"
        end
      end
    end
  end
end
