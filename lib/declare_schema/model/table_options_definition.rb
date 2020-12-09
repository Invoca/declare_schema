# frozen_string_literal: true

module DeclareSchema
  module Model
    class TableOptionsDefinition
      include Comparable

      # Example ActiveRecord Table Options String
      # "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci"
      ACTIVE_RECORD_TO_TABLE_OPTIONS_MAPPINGS = {
        'CHARSET' => :character_set,
        'COLLATE' => :collation
      }.freeze

      TABLE_OPTIONS_TO_SQL_MAPPINGS = {
        character_set: 'CHARACTER SET',
        collation:     'COLLATE'
      }.freeze

      class << self
        def for_model(model, old_table_name = nil)
          table_name    = old_table_name || model.table_name
          table_options = parse_table_options(model.connection.table_options(table_name))

          new(table_name, table_options)
        end

        private

        def parse_table_options(table_options)
          table_option_string = table_options&.dig(:options) || ""
          table_option_string.split(' ').reduce({}) do |options_hash, option|
            name, value = option.split('=', 2)
            if value && (standardized_name = ACTIVE_RECORD_TO_TABLE_OPTIONS_MAPPINGS[name])
              options_hash[standardized_name] = value
            end
            options_hash
          end
        end
      end

      attr_reader :table_name, :table_options

      def initialize(table_name, table_options = {})
        @table_name    = table_name
        @table_options = table_options
      end

      def to_key
        @key ||= [table_name, table_options].map(&:to_s)
      end

      def settings
        @settings ||= table_options.map { |name, value| "#{TABLE_OPTIONS_TO_SQL_MAPPINGS[name]} #{value}" if value }.compact.join(" ")
      end

      def hash
        to_key.hash
      end

      def <=>(rhs)
        to_key <=> rhs.to_key
      end

      def equivalent?(rhs)
        settings == rhs.settings
      end

      alias eql? ==

      def to_s
        settings
      end

      def alter_table_statement
        statement = "ALTER TABLE `#{table_name}` #{to_s};"
        "execute #{statement.inspect}"
      end
    end
  end
end
