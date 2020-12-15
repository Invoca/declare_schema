# frozen_string_literal: true

module DeclareSchema
  module Model
    class TableOptionsDefinition
      include Comparable

      TABLE_OPTIONS_TO_SQL_MAPPINGS = {
        charset:   'CHARACTER SET',
        collation: 'COLLATE'
      }.freeze

      class << self
        def for_model(model, old_table_name = nil)
          table_name    = old_table_name || model.table_name
          table_options = if model.connection.class.name.match?(/mysql/i)
                            mysql_table_options(model.connection, table_name)
                          else
                            {}
                          end

          new(table_name, table_options)
        end

        private

        def mysql_table_options(connection, table_name)
          database = connection.current_database
          defaults = connection.select_one(<<~EOS)
            SELECT CCSA.character_set_name, CCSA.collation_name
            FROM information_schema.`TABLES` T, information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA
            WHERE CCSA.collation_name = T.table_collation AND
                  T.table_schema = #{connection.quote_string(database)} AND
                  T.table_name = #{connection.quote_string(table_name)};
          EOS

          defaults["character_set_name"] or raise "character_set_name missing from #{defaults.inspect}"
          defaults["collation_name"]     or raise "collation_name missing from #{defaults.inspect}"

          {
            charset:   defaults["character_set_name"],
            collation: defaults["collation_name"]
          }
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
      alias to_s settings

      def alter_table_statement
        statement = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} #{to_s};"
        "execute #{statement.inspect}"
      end
    end
  end
end
