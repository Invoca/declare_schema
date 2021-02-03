# frozen_string_literal: true

require_relative 'column'

module DeclareSchema
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

      attr_reader :model, :name, :type, :sql_type, :position, :options, :sql_options

      TYPE_SYNONYMS = { timestamp: :datetime }.freeze # TODO: drop this synonym. -Colin

      SQL_OPTIONS     = [:limit, :precision, :scale, :null, :default, :charset, :collation].freeze
      NON_SQL_OPTIONS = [:ruby_default, :validates].freeze
      VALID_OPTIONS   = (SQL_OPTIONS + NON_SQL_OPTIONS).freeze
      OPTION_INDEXES  = Hash[VALID_OPTIONS.each_with_index.to_a].freeze

      VALID_OPTIONS.each do |option|
        define_method(option) { @options[option] }
      end

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

        @options.has_key?(:default) or @options[:default] = nil

        @options.has_key?(:null) or @options[:null] = false

        case type
        when :text
          if self.class.mysql_text_limits?
            @options[:default].nil? or raise MysqlTextMayNotHaveDefault, "when using MySQL, non-nil default may not be given for :text field #{model}##{@name}"
            @options[:limit] = self.class.round_up_mysql_text_limit(@options[:limit] || MYSQL_LONGTEXT_LIMIT)
          end
        when :string
          @options[:limit] or raise "limit: must be given for :string field #{model}##{@name}: #{@options.inspect}; do you want `limit: 255`?"
        when :bigint
          @type = :integer
          @options[:limit] = 8
        end

        # TODO: Do we really need to support a :sql_type option? Ideally drop it. -Colin
        @sql_type = @options.delete(:sql_type) || Column.sql_type(@type)

        if @sql_type.in?([:string, :text, :binary, :varbinary, :integer, :enum])
          @options[:limit] ||= Column.native_types[@sql_type][:limit]
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

        @options = Hash[@options.sort_by { |k, v| OPTION_INDEXES[k] }]

        @sql_options = @options.except(*NON_SQL_OPTIONS)
      end

      SQLITE_COLUMN_CLASS =
        begin
          ActiveRecord::ConnectionAdapters::SQLiteColumn
        rescue NameError
          NilClass
        end

      # returns the attributes for schema migrations as a Hash
      # omits name and position since those are meta-data above the schema
      def schema_attributes(col_spec)
        @options.merge(type: @type).tap do |attrs|
          attrs[:default] = Column.deserialize_default_value(col_spec, @sql_type, attrs[:default])
        end
      end
    end
  end
end
