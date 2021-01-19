# frozen_string_literal: true

module DeclareSchema
  class UnknownSqlTypeError < RuntimeError; end
  class MysqlTextMayNotHaveDefault < RuntimeError; end

  module Model
    class FieldSpec

      MYSQL_TINYTEXT_LIMIT    = 0xff
      MYSQL_TEXT_LIMIT        = 0xffff
      MYSQL_MEDIUMTEXT_LIMIT  = 0xff_ffff
      MYSQL_LONGTEXT_LIMIT    = 0xffff_ffff

      MYSQL_TEXT_LIMITS_ASCENDING = [MYSQL_TINYTEXT_LIMIT, MYSQL_TEXT_LIMIT, MYSQL_MEDIUMTEXT_LIMIT, MYSQL_LONGTEXT_LIMIT].freeze

      class << self
        def mysql_text_limits?
          if defined?(@mysql_text_limits)
            @mysql_text_limits
          else
            @mysql_text_limits = ActiveRecord::Base.connection.class.name.match?(/mysql/i)
          end
        end

        def round_up_mysql_text_limit(limit)
          MYSQL_TEXT_LIMITS_ASCENDING.find do |mysql_supported_text_limit|
            if limit <= mysql_supported_text_limit
              mysql_supported_text_limit
            end
          end or raise ArgumentError, "limit of #{limit} is too large for MySQL"
        end
      end

      attr_reader :model, :name, :type, :position, :options

      TYPE_SYNONYMS = { timestamp: :datetime }.freeze

      def initialize(model, name, type, position: 0, **options)
        # TODO: TECH-5116
        # Invoca change - searching for the primary key was causing an additional database read on every model load.  Assume
        # "id" which works for invoca.
        # raise ArgumentError, "you cannot provide a field spec for the primary key" if name == model.primary_key
        name == "id" and raise ArgumentError, "you cannot provide a field spec for the primary key"

        @model = model
        @name = name.to_sym
        type.is_a?(Symbol) or raise ArgumentError, "type must be a Symbol; got #{type.inspect}"
        @type = TYPE_SYNONYMS[type] || type
        @position = position
        @options = options.dup
        case type
        when :text
          if self.class.mysql_text_limits?
            @options[:default] and raise MysqlTextMayNotHaveDefault, "when using MySQL, default may not be given for :text field #{model}##{@name}"
            @options[:limit] = self.class.round_up_mysql_text_limit(@options[:limit] || MYSQL_LONGTEXT_LIMIT)
          end
        when :string
          @options[:limit] or raise "limit: must be given for :string field #{model}##{@name}: #{@options.inspect}; do you want `limit: 255`?"
        when :bigint
          @type = :integer
          @options = options.merge(limit: 8)
        end

        @sql_type = @options.delete(:sql_type) || # TODO: Do we really need to support :sql_type? If not, this can go away. -Colin
          if native_type?(@type)
            @type
          else
            if (field_class = DeclareSchema.to_class(@type))
              field_class::COLUMN_TYPE
            end or raise UnknownSqlTypeError, "#{@type.inspect} for #{model}##{@name}"
          end

        if @sql_type.in?([:string, :text, :binary, :varbinary, :integer, :enum])
          @options[:limit] ||= native_types[@sql_type][:limit]
        else
          @options.has_key?(:limit) and raise "unsupported limit: for SQL type #{@sql_type} in field #{model}##{@name}"
        end

        if @sql_type == :decimal
          @options[:precision] or raise 'precision: required for :decimal type'
          @options[:scale] or raise 'scale: required for :decimal type'
        else
          @options.has_key?(:precision) and raise "precision: only allowed for :decimal type"
          @options.has_key?(:scale) and raise "scale: only allowed for :decimal type"
        end

        if @type.in?([:text, :string])
          if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
            @options[:charset]   ||= model.table_options[:charset]   || Generators::DeclareSchema::Migration::Migrator.default_charset
            @options[:collation] ||= model.table_options[:collation] || Generators::DeclareSchema::Migration::Migrator.default_collation
          else
            @options.delete(:charset)
            @options.delete(:collation)
          end
        else
          @options[:charset]   and raise "charset may only given for :string and :text fields"
          @options[:collation] and raise "collation may only given for :string and :text fields"
        end
      end

      SQLITE_COLUMN_CLASS =
        begin
          ActiveRecord::ConnectionAdapters::SQLiteColumn
        rescue NameError
          NilClass
        end

      # returns the attributes for schema migrations as a Hash
      # omits name and position since those are meta-data above the schema
      def schema_attributes
        { type: @type }.merge(@options)
      end

      def sql_options
        @options.except(:ruby_default, :validates)
      end

      def limit
      end

      def precision
        @options[:precision]
      end

      def scale
        @options[:scale]
      end

      def null
        !:null.in?(@options) || @options[:null]
      end

      def default
        @options[:default]
      end

      def charset
        @options[:charset]
      end

      def collation
        @options[:collation]
      end

      def different_to?(col_spec)
        !same_as(col_spec)
      end

      def same_as(col_spec)
        @sql_type == col_spec.type &&
          same_attributes?(col_spec) &&
            (!type.in?([:text, :string]) || same_charset_and_collation?(table_name, col_spec))
      end

      private

      def same_attributes?(col_spec)
        schema_attributes.all? do |k, v|
          if k == :default
            case Rails::VERSION::MAJOR
            when 4
              col_spec.type_cast_from_database(col_spec.default) == col_spec.type_cast_from_database(v)
            else
              cast_type = ActiveRecord::Base.connection.lookup_cast_type_from_column(col_spec) or raise "cast_type not found for #{col_spec.inspect}"
              cast_type.deserialize(col_spec.default) == cast_type.deserialize(v)
            end
          else
            col_value = col_spec.send(k)
            if col_value.nil? && (native_type = native_types[type])
              col_value = native_type[k]
            end
            col_value == v
          end
        end
      end

      def same_charset_and_collation?(table_name, col_spec)
        current_collation_and_charset = collation_and_charset_for_column(table_name, col_spec)

        collation == current_collation_and_charset[:collation] &&
          charset == current_collation_and_charset[:charset]
      end

      def collation_and_charset_for_column(table_name, col_spec)
        column_name   = col_spec.name
        connection    = ActiveRecord::Base.connection

        if connection.class.name.match?(/mysql/i)
          database_name = connection.current_database

          defaults = connection.select_one(<<~EOS)
            SELECT C.character_set_name, C.collation_name
            FROM information_schema.`COLUMNS` C
            WHERE C.table_schema = '#{connection.quote_string(database_name)}' AND
                  C.table_name = '#{connection.quote_string(table_name)}' AND
                  C.column_name = '#{connection.quote_string(column_name)}';
          EOS

          defaults["character_set_name"] or raise "character_set_name missing from #{defaults.inspect}"
          defaults["collation_name"]     or raise "collation_name missing from #{defaults.inspect}"

          {
            charset:   defaults["character_set_name"],
            collation: defaults["collation_name"]
          }
        else
          {}
        end
      end

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
        Generators::DeclareSchema::Migration::Migrator.native_types
      end
    end
  end
end
