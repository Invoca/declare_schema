# frozen_string_literal: true

module DeclareSchema
  class UnknownSqlTypeError < RuntimeError; end

  module Model
    # This class is a wrapper for the ActiveRecord::...::Column class
    class Column
      class << self
        def native_type?(type)
          type != :primary_key && native_types.has_key?(type)
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
            end
          end
        end

        def sql_type(type)
          if native_type?(type)
            type
          else
            if (field_class = DeclareSchema.to_class(type))
              field_class::COLUMN_TYPE
            end or raise UnknownSqlTypeError, "#{type.inspect} for type #{type.inspect}"
          end
        end

        def deserialize_default_value(column, sql_type, default_value)
          sql_type or raise ArgumentError, "must pass sql_type; got #{sql_type.inspect}"

          case Rails::VERSION::MAJOR
          when 4
            # TODO: Delete this Rails 4 support ASAP! This could be wrong, since it's using the type of the old column...which
            # might be getting migrated to a new type. We should be using just sql_type as below. -Colin
            column.type_cast_from_database(default_value)
          else
            cast_type = ActiveRecord::Base.connection.send(:lookup_cast_type, sql_type) or
              raise "cast_type not found for #{sql_type}"
            cast_type.deserialize(default_value)
          end
        end

        # Normalizes schema attributes for the specific database adapter that is currently running
        # Note that the un-normalized attributes are still useful for generating migrations because those
        # may be run with a different adapter.
        # This method never mutates its argument. In fact it freezes it to be certain.
        def normalize_schema_attributes(schema_attributes)
          schema_attributes[:type] or raise ArgumentError, ":type key not found; keys: #{schema_attributes.keys.inspect}"
          schema_attributes.freeze

          case ActiveRecord::Base.connection.class.name
          when /mysql/i
            schema_attributes
          when /sqlite/i
            case schema_attributes[:type]
            when :text
              schema_attributes = schema_attributes.merge(limit: nil)
            when :integer
              schema_attributes = schema_attributes.dup
              schema_attributes[:limit] ||= 8
            end
            schema_attributes
          else
            schema_attributes
          end
        end

        def equivalent_schema_attributes?(schema_attributes_lhs, schema_attributes_rhs)
          normalize_schema_attributes(schema_attributes_lhs) == normalize_schema_attributes(schema_attributes_rhs)
        end
      end

      attr_reader :sql_type

      def initialize(model, current_table_name, column)
        @model = model or raise ArgumentError, "must pass model"
        @current_table_name = current_table_name or raise ArgumentError, "must pass current_table_name"
        @column = column or raise ArgumentError, "must pass column"
        @sql_type = self.class.sql_type(@column.type)
      end

      SCHEMA_KEYS = [:type, :limit, :precision, :scale, :null, :default].freeze

      # omits keys with nil values
      def schema_attributes
        SCHEMA_KEYS.each_with_object({}) do |key, result|
          value =
            case key
            when :default
              self.class.deserialize_default_value(@column, @sql_type, @column.default)
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
