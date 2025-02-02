# frozen_string_literal: true

require 'digest/sha2'

module DeclareSchema
  module Model
    class IndexDefinition
      include Comparable

      OPTIONS = [:name, :unique, :where, :length].freeze
      attr_reader :columns, :allow_equivalent, :table_name, *OPTIONS

      alias fields columns # TODO: change callers to use columns. -Colin

      class IndexNameTooLongError < RuntimeError; end

      PRIMARY_KEY_NAME = "PRIMARY"

      def initialize(columns, table_name:, name: nil, allow_equivalent: true, unique: false, where: nil, length: nil)
        @table_name = table_name
        @name = name&.to_s || self.class.default_index_name(table_name, columns)
        @columns = Array.wrap(columns).map(&:to_s)
        @allow_equivalent = allow_equivalent
        unique.in?([false, true]) or raise ArgumentError, "unique must be true or false: got #{unique.inspect}"
        if @name == PRIMARY_KEY_NAME
          unique or raise ArgumentError, "primary key index must be unique"
        end
        @unique = unique

        if DeclareSchema.max_index_and_constraint_name_length && @name.length > DeclareSchema.max_index_and_constraint_name_length
          raise IndexNameTooLongError, "Index '#{@name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters. Give it a shorter name, or adjust DeclareSchema.max_index_and_constraint_name_length if you know your database can accept longer names."
        end

        if where
          @where = where.start_with?('(') ? where : "(#{where})"
        end

        @length = self.class.normalize_index_length(length, columns: @columns)
      end

      class << self
        # extract IndexSpecs from an existing table
        # includes the PRIMARY KEY index
        def for_table(table_name, ignore_indexes, connection)
          primary_key_columns = Array(connection.primary_key(table_name))
          primary_key_columns.present? or raise "could not find primary key for table #{table_name} in #{connection.columns(table_name).inspect}"

          primary_key_found = false
          index_definitions = connection.indexes(table_name).map do |index|
            next if ignore_indexes.include?(index.name)

            if index.name == PRIMARY_KEY_NAME
              index.columns == primary_key_columns && index.unique or
                raise "primary key on #{table_name} was not unique on #{primary_key_columns} (was unique=#{index.unique} on #{index.columns})"
              primary_key_found = true
            end
            new(index.columns, name: index.name, table_name: table_name, unique: index.unique, where: index.where, length: index.lengths)
          end.compact

          if !primary_key_found
            index_definitions << new(primary_key_columns, name: PRIMARY_KEY_NAME, table_name: table_name, unique: true)
          end
          index_definitions
        end

        def default_index_name(table_name, columns)
          if DeclareSchema.current_adapter == 'postgresql'
            long_index_name(table_name, columns)
          else
            longest_valid_index_name(table_name, columns)
          end
        end

        # This method normalizes the length option to be either nil or a Hash of Symbol column names to lengths,
        # so that we can safely compare what the user specified with what we get when querying the database schema.
        # @return [Hash<Symbol, nil>]
        def normalize_index_length(length, columns:)
          case length
          when nil, {}
            nil
          when Integer
            if columns.size == 1
              { columns.first.to_sym => length }
            else
              raise ArgumentError, "Index length of Integer only allowed when exactly one column; got #{length.inspect} for #{columns.inspect}"
            end
          when Hash
            length.transform_keys(&:to_sym)
          else
            raise ArgumentError, "Index length must be nil or Integer or a Hash of column names to lengths; got #{length.inspect} for #{columns.inspect}"
          end
        end

        private

        SHA_SUFFIX_LENGTH = 4

        def shorten_name(name, max_len)
          if name.size <= max_len
            name
          else
            name_prefix = name.first(max_len >= SHA_SUFFIX_LENGTH*2 ? (max_len - SHA_SUFFIX_LENGTH) : ((max_len + 1)/2))
            sha = Digest::SHA256.hexdigest(name)
            (name_prefix + sha).first(max_len)
          end
        end

        def longest_valid_index_name(table_name, columns)
          index_name = nil
          [:long_index_name, :short_index_name].find do |method_name|
            index_name = send(method_name, table_name, columns)
            if DeclareSchema.max_index_and_constraint_name_length.nil? || index_name.length <= DeclareSchema.max_index_and_constraint_name_length
              break index_name
            end
          end or raise IndexNameTooLongError,
                       "Default index name '#{index_name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters. Use the `name:` option to give it a shorter name, or adjust DeclareSchema.max_index_and_constraint_name_length if you know your database can accept longer names." # rubocop:disable Layout/LineLength
        end

        def long_index_name(table_name, columns)
          "index_#{table_name}_on_#{Array(columns).join("_and_")}"
        end

        def short_index_name(table_name, columns)
          columns_suffix = "__" + Array(columns).join('_')
          if DeclareSchema.max_index_and_constraint_name_length.nil?
            table_name + columns_suffix
          else
            max_name_len = [DeclareSchema.max_index_and_constraint_name_length - columns_suffix.length, 0].max
            shorten_name(table_name, max_name_len) + columns_suffix
          end
        end
      end

      def primary_key?
        name == PRIMARY_KEY_NAME
      end

      def options
        @options ||=
          OPTIONS.each_with_object({}) do |option, result|
            result[option] = send(option)
          end.freeze
      end

      # Unique key for this object. Used for equality checking.
      def to_key
        @to_key ||= [name, *settings].freeze
      end

      # The index settings for this object. Used for equivalence checking. Does not include the name.
      def settings
        @settings ||= [columns, options.except(:name)].freeze
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

      def with_name(new_name)
        self.class.new(@columns, name: new_name, table_name: @table_name, unique: @unique, allow_equivalent: @allow_equivalent, where: @where, length: @length)
      end

      alias eql? ==
    end
  end
end
