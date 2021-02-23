# frozen_string_literal: true

module DeclareSchema
  class UnknownTypeError < RuntimeError; end

  module Model
    # This class is a wrapper for the ActiveRecord::...::Column class
    class Column
      class << self
        def native_type?(type)
          type != :primary_key && (native_types.empty? || native_types[type]) # empty will happen with NullDBAdapter used in assets:precompile
        end

        # MySQL example:
        # { primary_key: "bigint auto_increment PRIMARY KEY",
        #   string: { name: "varchar", limit: 255 },
        #   text: { name: "text", limit: 65535},
        #   integer: {name: "int", limit: 4 },
        #   float: {name: "float", limit: 24 },
        #   decimal: { name: "decimal" },
        #   datetime: { name: "datetime" },
        #   timestamp: { name: "timestamp" },
        #   time: { name: "time" },
        #   date: { name: "date" },
        #   binary: { name>: "blob", limit: 65535 },
        #   boolean: { name: "tinyint", limit: 1 },
        #   json: { name: "json" } }
        #
        # SQLite example:
        # { primary_key: "integer PRIMARY KEY AUTOINCREMENT NOT NULL",
        #  string: { name: "varchar" },
        #  text: { name: "text"},
        #  integer: { name: "integer" },
        #  float: { name: "float" },
        #  decimal: { name: "decimal" },
        #  datetime: { name: "datetime" },
        #  time: { name: "time" },
        #  date: { name: "date" },
        #  binary: { name: "blob" },
        #  boolean: { name: "boolean" },
        #  json: { name: "json" } }
        def native_types
          @native_types ||= ActiveRecord::Base.connection.native_database_types.tap do |types|
            if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
              types[:text][:limit]    ||= 0xffff
              types[:binary][:limit]  ||= 0xffff

              types[:varbinary] ||= { name: "varbinary" } # TODO: :varbinary is an Invoca addition to Rails; make it a configurable option
            end
          end
        end

        def deserialize_default_value(column, type, default_value)
          type or raise ArgumentError, "must pass type; got #{type.inspect}"

          case Rails::VERSION::MAJOR
          when 4
            # TODO: Delete this Rails 4 support ASAP! This could be wrong, since it's using the type of the old column...which
            # might be getting migrated to a new type. We should be using just type as below. -Colin
            column.type_cast_from_database(default_value)
          else
            cast_type = ActiveRecord::Base.connection.send(:lookup_cast_type, type) or
              raise "cast_type not found for #{type}"
            cast_type.deserialize(default_value)
          end
        end

        # Normalizes schema attributes for the given database adapter name.
        # Note that the un-normalized attributes are still useful for generating migrations because those
        # may be run with a different adapter.
        # This method never mutates its argument.
        def normalize_schema_attributes(schema_attributes, db_adapter_name)
          case schema_attributes[:type]
          when :boolean
            schema_attributes.reverse_merge(limit: 1)
          when :integer
            schema_attributes.reverse_merge(limit: 8) if db_adapter_name.match?(/sqlite/i)
          when :float
            schema_attributes.except(:limit)
          when :text
            schema_attributes.except(:limit)          if db_adapter_name.match?(/sqlite/i)
          when :datetime
            schema_attributes.reverse_merge(precision: 0)
          when NilClass
            raise ArgumentError, ":type key not found; keys: #{schema_attributes.keys.inspect}"
          end || schema_attributes
        end

        def equivalent_schema_attributes?(schema_attributes_lhs, schema_attributes_rhs)
          db_adapter_name = ActiveRecord::Base.connection.class.name
          normalized_lhs = normalize_schema_attributes(schema_attributes_lhs, db_adapter_name)
          normalized_rhs = normalize_schema_attributes(schema_attributes_rhs, db_adapter_name)

          normalized_lhs == normalized_rhs
        end
      end

      attr_reader :type

      def initialize(model, current_table_name, column)
        @model = model or raise ArgumentError, "must pass model"
        @current_table_name = current_table_name or raise ArgumentError, "must pass current_table_name"
        @column = column or raise ArgumentError, "must pass column"
        @type = @column.type
        self.class.native_type?(@type) or raise UnknownTypeError, "#{@type.inspect}"
      end

      SCHEMA_KEYS = [:type, :limit, :precision, :scale, :null, :default].freeze

      # omits keys with nil values
      def schema_attributes
        SCHEMA_KEYS.each_with_object({}) do |key, result|
          value =
            case key
            when :default
              self.class.deserialize_default_value(@column, @type, @column.default)
            else
              col_value = @column.send(key)
              if col_value.nil? && (native_type = self.class.native_types[@column.type])
                native_type[key]
              else
                col_value
              end
            end

          result[key] = value unless value.nil?
        end.tap do |result|
          if ActiveRecord::Base.connection.class.name.match?(/mysql/i) && @column.type.in?([:string, :text])
            result.merge!(collation_and_charset_for_column(@current_table_name, @column.name))
          end
        end
      end

      private

      def collation_and_charset_for_column(current_table_name, column_name)
        connection    = ActiveRecord::Base.connection
        connection.class.name.match?(/mysql/i) or raise ArgumentError, "only supported for MySQL"

        database_name = connection.current_database

        defaults = connection.select_one(<<~EOS)
          SELECT C.character_set_name, C.collation_name
          FROM information_schema.`COLUMNS` C
          WHERE C.table_schema = '#{connection.quote_string(database_name)}' AND
                C.table_name = '#{connection.quote_string(current_table_name)}' AND
                C.column_name = '#{connection.quote_string(column_name)}';
        EOS

        defaults && defaults["character_set_name"] or raise "character_set_name missing from #{defaults.inspect} from #{database_name}.#{current_table_name}.#{column_name}"
        defaults && defaults["collation_name"]     or raise "collation_name missing from #{defaults.inspect}"

        {
          charset:   defaults["character_set_name"],
          collation: defaults["collation_name"]
        }
      end
    end
  end
end
