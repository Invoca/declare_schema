# frozen_string_literal: true

module DeclareSchema
  module Model
    class FieldSpec
      class UnknownSqlTypeError < RuntimeError; end

      MYSQL_TINYTEXT_LIMIT    = 0xff
      MYSQL_TEXT_LIMIT        = 0xffff
      MYSQL_MEDIUMTEXT_LIMIT  = 0xff_ffff
      MYSQL_LONGTEXT_LIMIT    = 0xffff_ffff

      MYSQL_TEXT_LIMITS_ASCENDING = [MYSQL_TINYTEXT_LIMIT, MYSQL_TEXT_LIMIT, MYSQL_MEDIUMTEXT_LIMIT, MYSQL_LONGTEXT_LIMIT].freeze

      class << self
        # method for easy stubbing in tests
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

      def initialize(model, name, type, options = {})
        # Invoca change - searching for the primary key was causing an additional database read on every model load.  Assume
        # "id" which works for invoca.
        # raise ArgumentError, "you cannot provide a field spec for the primary key" if name == model.primary_key
        name == "id" and raise ArgumentError, "you cannot provide a field spec for the primary key"

        @model = model
        @name = name.to_sym
        type.is_a?(Symbol) or raise ArgumentError, "type must be a Symbol; got #{type.inspect}"
        @type = type
        position_option = options.delete(:position)
        @options = options

        case type
        when :text
          @options[:default] and raise "default may not be given for :text field #{model}##{@name}"
          if self.class.mysql_text_limits?
            @options[:limit] = self.class.round_up_mysql_text_limit(@options[:limit] || MYSQL_LONGTEXT_LIMIT)
          end
        when :string
          @options[:limit] or raise "limit must be given for :string field #{model}##{@name}: #{@options.inspect}; do you want `limit: 255`?"
        else
          @options[:collation] and raise "collation may only given for :string and :text fields"
          @options[:charset]   and raise "charset may only given for :string and :text fields"
        end
        @position = position_option || model.field_specs.length
      end

      TYPE_SYNONYMS = { timestamp: :datetime }.freeze

      SQLITE_COLUMN_CLASS =
        begin
          ActiveRecord::ConnectionAdapters::SQLiteColumn
        rescue NameError
          NilClass
        end

      def sql_type
        @options[:sql_type] || begin
                                if native_type?(type)
                                  type
                                else
                                  field_class = DeclareSchema.to_class(type)
                                  field_class && field_class::COLUMN_TYPE or raise UnknownSqlTypeError, "#{type.inspect} for #{model}##{@name}"
                                end
                              end
      end

      def sql_options
        @options.except(:ruby_default, :validates)
      end

      def limit
        @options[:limit] || native_types[sql_type][:limit]
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

      def collation
        if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
          (@options[:collation] || model.table_options[:collation] || Generators::DeclareSchema::Migration::Migrator.default_collation).to_s
        end
      end

      def charset
        if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
          (@options[:charset] || model.table_options[:charset] || Generators::DeclareSchema::Migration::Migrator.default_charset).to_s
        end
      end

      def same_type?(col_spec)
        type = sql_type
        normalized_type           = TYPE_SYNONYMS[type] || type
        normalized_col_spec_type  = TYPE_SYNONYMS[col_spec.type] || col_spec.type
        normalized_type == normalized_col_spec_type
      end

      def different_to?(table_name, col_spec)
        !same_as(table_name, col_spec)
      end

      def same_as(table_name, col_spec)
        same_type?(col_spec) &&
          same_attributes?(col_spec) &&
          (!type.in?([:text, :string]) || same_charset_and_collation?(table_name, col_spec))
      end

      private

      def same_attributes?(col_spec)
        native_type = native_types[type]
        check_attributes = [:null, :default]
        check_attributes += [:precision, :scale] if sql_type == :decimal && !col_spec.is_a?(SQLITE_COLUMN_CLASS)  # remove when rails fixes https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/2872
        check_attributes -= [:default] if sql_type == :text && col_spec.class.name =~ /mysql/i
        check_attributes << :limit if sql_type.in?([:string, :binary, :varbinary, :integer, :enum]) ||
                                      (sql_type == :text && self.class.mysql_text_limits?)
        check_attributes.all? do |k|
          if k == :default
            case Rails::VERSION::MAJOR
            when 4
              col_spec.type_cast_from_database(col_spec.default) == col_spec.type_cast_from_database(default)
            else
              cast_type = ActiveRecord::Base.connection.lookup_cast_type_from_column(col_spec) or raise "cast_type not found for #{col_spec.inspect}"
              cast_type.deserialize(col_spec.default) == cast_type.deserialize(default)
            end
          else
            col_value = col_spec.send(k)
            if col_value.nil? && native_type
              col_value = native_type[k]
            end
            col_value == send(k)
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
            WHERE C.table_schema = #{connection.quote_string(database_name)} AND
                  C.table_name = #{connection.quote_string(table_name)} AND
                  C.column_name = #{connection.quote_string(column_name)};
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
        type.to_sym != :primary_key && native_types.has_key?(type)
      end

      def native_types
        Generators::DeclareSchema::Migration::Migrator.native_types
      end
    end
  end
end
