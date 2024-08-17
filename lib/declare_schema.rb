# frozen_string_literal: true

require 'active_support'
require 'active_support/all'
require_relative 'declare_schema/version'
require 'rubygems/version'

ActiveSupport::Dependencies.autoload_paths |= [__dir__]

module DeclareSchema
  class Boolean; end

  PLAIN_TYPES = {
    boolean:  Boolean,
    date:     Date,
    datetime: ActiveSupport::TimeWithZone,
    time:     Time,
    integer:  Integer,
    decimal:  BigDecimal,
    float:    Float,
    string:   String,
    text:     String
  }.freeze

  SEMVER_8 = Gem::Version.new('8.0.0').freeze

  @default_charset                      = "utf8mb4"
  @default_collation                    = "utf8mb4_bin"
  @default_text_limit                   = 0xffff_ffff
  @default_string_limit                 = nil
  @default_null                         = false
  @default_generate_foreign_keys        = true
  @default_generate_indexing            = true
  @db_migrate_command                   = "bundle exec rails db:migrate"
  @max_index_and_constraint_name_length = 64  # limit for MySQL

  class << self
    attr_writer :mysql_version
    attr_reader :default_text_limit, :default_string_limit, :default_null,
                :default_generate_foreign_keys, :default_generate_indexing, :db_migrate_command,
                :max_index_and_constraint_name_length

    def to_class(type)
      case type
      when Class
        type
      when Symbol, String
        PLAIN_TYPES[type.to_sym]
      else
        raise ArgumentError, "expected Class or Symbol or String: got #{type.inspect}"
      end
    end

    def mysql_version
      if defined?(@mysql_version)
        @mysql_version
      else
        @mysql_version =
          if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
            version_string = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
            Gem::Version.new(version_string)
          end
      end
    end

    def normalize_charset(charset)
      if mysql_version && mysql_version >= SEMVER_8 && charset == 'utf8'
        'utf8mb3'
      else
        charset
      end
    end

    def normalize_collation(collation)
      if mysql_version && mysql_version >= SEMVER_8
        collation.sub(/\Autf8_/, 'utf8mb3_')
      else
        collation
      end
    end

    def default_charset=(charset)
      charset.is_a?(String) or raise ArgumentError, "charset must be a string (got #{charset.inspect})"
      @default_charset_before_normalization = charset
      @default_charset = nil
    end

    def default_charset
      @default_charset ||= normalize_charset(@default_charset_before_normalization)
    end

    def default_collation=(collation)
      collation.is_a?(String) or raise ArgumentError, "collation must be a string (got #{collation.inspect})"
      @default_collation_before_normalization = collation
      @default_collation = nil
    end

    def default_collation
      @default_collation ||= normalize_collation(@default_collation_before_normalization)
    end

    def default_text_limit=(text_limit)
      text_limit.nil? or text_limit.is_a?(Integer) or raise ArgumentError, "text limit must be an integer or nil (got #{text_limit.inspect})"
      @default_text_limit = text_limit
    end

    def default_string_limit=(string_limit)
      string_limit.nil? or string_limit.is_a?(Integer) or raise ArgumentError, "string limit must be an integer or nil (got #{string_limit.inspect})"
      @default_string_limit = string_limit
    end

    def default_null=(null)
      null.in?([true, false, nil]) or raise ArgumentError, "null must be either true, false, or nil (got #{null.inspect})"
      @default_null = null
    end

    def default_generate_foreign_keys=(generate_foreign_keys)
      generate_foreign_keys.in?([true, false]) or raise ArgumentError, "generate_foreign_keys must be either true or false (got #{generate_foreign_keys.inspect})"
      @default_generate_foreign_keys = generate_foreign_keys
    end

    def default_generate_indexing=(generate_indexing)
      generate_indexing.in?([true, false]) or raise ArgumentError, "generate_indexing must be either true or false (got #{generate_indexing.inspect})"
      @default_generate_indexing = generate_indexing
    end

    def default_schema(&block)
      if block.nil?
        @default_schema # equivalent to attr_reader :default_schema
      else
        block.respond_to?(:call) or raise "default_schema must be passed a block that responds to call"
        @default_schema = block
      end
    end

    def clear_default_schema
      @default_schema = nil
    end

    def db_migrate_command=(db_migrate_command)
      db_migrate_command.is_a?(String) or raise ArgumentError, "db_migrate_command must be a string (got #{db_migrate_command.inspect})"
      @db_migrate_command = db_migrate_command
    end

    def max_index_and_constraint_name_length=(length)
      length.is_a?(Integer) || length.nil? or raise ArgumentError, "max_index_and_constraint_name_length must be an Integer or nil (meaning unlimited)"
      @max_index_and_constraint_name_length = length
    end

    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new('3.0', 'DeclareSchema')
    end

    def current_adapter(model_class = ActiveRecord::Base)
      if Rails::VERSION::MAJOR >= 7
        model_class.connection_db_config.adapter
      else
        model_class.connection_config[:adapter]
      end
    end
  end
end

require 'declare_schema/extensions/active_record/fields_declaration'
require 'declare_schema/field_declaration_dsl'
require 'declare_schema/model'
require 'declare_schema/model/field_spec'
require 'declare_schema/model/index_definition'
require 'declare_schema/model/foreign_key_definition'
require 'declare_schema/model/table_options_definition'

require 'declare_schema/railtie' if defined?(Rails)
