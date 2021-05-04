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

      attr_reader :model, :name, :type, :position, :options, :sql_options

      TYPE_SYNONYMS = { timestamp: :datetime }.freeze # TODO: drop this synonym. -Colin

      SQL_OPTIONS     = [:limit, :precision, :scale, :null, :default, :charset, :collation].freeze
      NON_SQL_OPTIONS = [:ruby_default, :validates].freeze
      VALID_OPTIONS   = (SQL_OPTIONS + NON_SQL_OPTIONS).freeze
      OPTION_INDEXES  = Hash[VALID_OPTIONS.each_with_index.to_a].freeze

      VALID_OPTIONS.each do |option|
        define_method(option) { @options[option] }
      end

      def initialize(model, name, type, position: 0, **options)
        qualified_name = -> { "#{model.name}##{name}" }

        _declared_primary_key = model._declared_primary_key

        name.to_s == _declared_primary_key and raise ArgumentError, "#{qualified_name.()}: you may not provide a field spec for the primary key #{name.inspect}"

        @model = model
        @name = name.to_sym
        type.is_a?(Symbol) or raise ArgumentError, "#{qualified_name.()}: type must be a Symbol; got #{type.inspect}"
        @type = TYPE_SYNONYMS[type] || type
        @position = position
        @options = options.dup

        @options.has_key?(:null) or @options[:null] = ::DeclareSchema.default_null
        @options[:null].nil? and raise "#{qualified_name.()}: null: must be provided for field #{model}##{@name}: #{@options.inspect} since ::DeclareSchema#default_null is set to 'nil'; do you want `null: false`?"

        case @type
        when :text
          if self.class.mysql_text_limits?
            @options[:default].nil? or raise MysqlTextMayNotHaveDefault, "#{qualified_name.()}: when using MySQL, non-nil default may not be given for :text field #{model}##{@name}"
            @options[:limit] ||= ::DeclareSchema.default_text_limit or
                  raise("#{qualified_name.()}: limit: must be provided for :text field #{model}##{@name}: #{@options.inspect} since ::DeclareSchema#default_text_limit is set to 'nil'; do you want `limit: 0xffff_ffff`?")
            @options[:limit] = self.class.round_up_mysql_text_limit(@options[:limit])
          else
            @options.delete(:limit)
          end
        when :string
          @options[:limit] ||= ::DeclareSchema.default_string_limit or raise "#{qualified_name.()}: limit: must be provided for :string field #{model}##{@name}: #{@options.inspect} since ::DeclareSchema#default_string_limit is set to 'nil'; do you want `limit: 255`?"
        when :bigint
          @type = :integer
          @options[:limit] = 8
        end

        Column.native_type?(@type) or raise UnknownTypeError, "#{qualified_name.()}: #{@type.inspect} not found in #{Column.native_types.inspect} for adapter #{::ActiveRecord::Base.connection.class.name}"

        if @type.in?([:string, :text, :binary, :integer, :enum])
          @options[:limit] ||= Column.native_types.dig(@type, :limit)
        else
          @type != :decimal && @options.has_key?(:limit) and warn("unsupported limit: for SQL type #{@type} in field #{model}##{@name}")
          @options.delete(:limit)
        end

        if @type == :decimal
          @options[:precision] or warn("precision: required for :decimal type in field #{model}##{@name}")
          @options[:scale] or warn("scale: required for :decimal type in field #{model}##{@name}")
        else
          if @type != :datetime
            @options.has_key?(:precision) and warn("precision: only allowed for :decimal type or :datetime for SQL type #{@type} in field #{model}##{@name}")
          end
          @options.has_key?(:scale) and warn("scale: only allowed for :decimal type for SQL type #{@type} in field #{model}##{@name}")
        end

        if @type.in?([:text, :string])
          if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
            @options[:charset]   ||= model._table_options&.[](:charset)   || ::DeclareSchema.default_charset
            @options[:collation] ||= model._table_options&.[](:collation) || ::DeclareSchema.default_collation
          else
            @options.delete(:charset)
            @options.delete(:collation)
          end
        else
          @options[:charset]   and warn("charset may only given for :string and :text fields for SQL type #{@type} in field #{model}##{@name}")
          @options[:collation] and warn("collation may only given for :string and :text fields for SQL type #{@type} in field #{model}##{@name}")
        end

        @options = Hash[@options.sort_by { |k, _v| OPTION_INDEXES[k] || 9999 }]

        @sql_options = @options.slice(*SQL_OPTIONS)
      end

      # returns the attributes for schema migrations as a Hash
      # omits name and position since those are meta-data above the schema
      # omits keys with nil values
      def schema_attributes(col_spec)
        @sql_options.merge(type: @type).tap do |attrs|
          attrs[:default] = Column.deserialize_default_value(col_spec, @type, attrs[:default])
        end.compact
      end
    end
  end
end
