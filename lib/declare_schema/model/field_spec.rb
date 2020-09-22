# frozen_string_literal: true

module DeclareSchema
  module Model
    class FieldSpec
      class UnknownSqlTypeError < RuntimeError; end

      MYSQL_TINYTEXT_LIMIT    =        0xff
      MYSQL_TEXT_LIMIT        =      0xffff
      MYSQL_MEDIUMTEXT_LIMIT  =   0xff_ffff
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

      def initialize(model, name, type, options = {})
        # Invoca change - searching for the primary key was causing an additional database read on every model load.  Assume
        # "id" which works for invoca.
        # raise ArgumentError, "you cannot provide a field spec for the primary key" if name == model.primary_key
        raise ArgumentError, "you cannot provide a field spec for the primary key" if name == "id"
        self.model = model
        self.name = name.to_sym
        self.type = type.is_a?(String) ? type.to_sym : type
        position = options.delete(:position)
        self.options = options

        case type
        when :text
          options[:default] and raise "default may not be given for :text field #{model}##{name}"
          if self.class.mysql_text_limits?
            options[:limit] = self.class.round_up_mysql_text_limit(options[:limit] || MYSQL_LONGTEXT_LIMIT)
          end
        when :string
          options[:limit] or raise "limit must be given for :string field #{model}##{name}: #{self.options.inspect}; do you want 255?"
        end
        self.position = position || model.field_specs.length
      end

      attr_accessor :model, :name, :type, :position, :options

      TYPE_SYNONYMS = [[:timestamp, :datetime]].freeze

      SQLITE_COLUMN_CLASS =
        begin
          ActiveRecord::ConnectionAdapters::SQLiteColumn
        rescue NameError
          NilClass
        end

      def sql_type
        options[:sql_type] or begin
                                if native_type?(type)
                                  type
                                else
                                  field_class = DeclareSchema.to_class(type)
                                  field_class && field_class::COLUMN_TYPE or raise UnknownSqlTypeError, "#{type.inspect} for #{model}.#{name}"
                                end
                              end
      end

      def sql_options
        @options.except(:ruby_default, :validates)
      end

      def limit
        options[:limit] || native_types[sql_type][:limit]
      end

      def precision
        options[:precision]
      end

      def scale
        options[:scale]
      end

      def null
        !:null.in?(options) || options[:null]
      end

      def default
        options[:default]
      end

      def comment
        options[:comment]
      end

      def same_type?(col_spec)
        t = sql_type
        TYPE_SYNONYMS.each do |synonyms|
          if t.in? synonyms
            return col_spec.type.in?(synonyms)
          end
        end
        t == col_spec.type
      end

      def different_to?(col_spec)
        !same_type?(col_spec) ||
          # we should be able to use col_spec.comment, but col_spec has
          # a nil table_name for some strange reason.
          (model.table_exists? &&
            ActiveRecord::Base.respond_to?(:column_comment) &&
            !(col_comment = ActiveRecord::Base.column_comment(col_spec.name, model.table_name)).nil? &&
            col_comment != comment
          ) ||
          begin
            native_type = native_types[type]
            check_attributes = [:null, :default]
            check_attributes += [:precision, :scale] if sql_type == :decimal && !col_spec.is_a?(SQLITE_COLUMN_CLASS)  # remove when rails fixes https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/2872
            check_attributes -= [:default] if sql_type == :text && col_spec.class.name =~ /mysql/i
            check_attributes << :limit if sql_type.in?([:string, :binary, :varbinary, :integer, :enum]) ||
                                          (sql_type == :text && self.class.mysql_text_limits?)
            check_attributes.any? do |k|
              if k == :default
                case Rails::VERSION::MAJOR
                when 4
                  col_spec.type_cast_from_database(col_spec.default) != col_spec.type_cast_from_database(default)
                else
                  cast_type = ActiveRecord::Base.connection.lookup_cast_type_from_column(col_spec) or raise "cast_type not found for #{col_spec.inspect}"
                  cast_type.deserialize(col_spec.default) != cast_type.deserialize(default)
                end
              else
                col_value = col_spec.send(k)
                if col_value.nil? && native_type
                  col_value = native_type[k]
                end
                col_value != self.send(k)
              end
            end
          end
      end

      private

      def native_type?(type)
        type.in?(native_types.keys - [:primary_key])
      end

      def native_types
        Generators::DeclareSchema::Migration::Migrator.native_types
      end
    end
  end
end
