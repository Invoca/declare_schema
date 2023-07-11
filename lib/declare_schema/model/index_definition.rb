# frozen_string_literal: true

require 'digest/sha2'

module DeclareSchema
  module Model
    class IndexDefinition
      include Comparable

      # TODO: replace `fields` with `columns` and remove alias. -Colin
      attr_reader :table_name, :fields, :explicit_name, :name, :unique, :where
      alias columns fields

      class IndexNameTooLongError < RuntimeError; end

      PRIMARY_KEY_NAME = "PRIMARY"

      def initialize(table_name, fields, name: nil, allow_equivalent: false, unique: false, where: nil)
        @table_name = table_name
        @fields = Array.wrap(fields).map(&:to_s)
        @explicit_name = name unless allow_equivalent
        @name = name || self.class.default_index_name(@table_name, @fields)
        @unique = unique || @name == PRIMARY_KEY_NAME || false

        if DeclareSchema.max_index_and_constraint_name_length && @name.length > DeclareSchema.max_index_and_constraint_name_length
          raise IndexNameTooLongError, "Index '#{@name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters. Give it a shorter name, or adjust DeclareSchema.max_index_and_constraint_name_length if you know your database can accept longer names."
        end

        if where
          @where = where.start_with?('(') ? where : "(#{where})"
        end
      end

      class << self
        # extract IndexSpecs from an existing table
        # includes the PRIMARY KEY index
        def for_model(model, table_name)
          table_name ||= model.table_name
          primary_key_columns = Array(model.connection.primary_key(table_name))
          primary_key_columns.present? or raise "could not find primary key for table #{table_name} in #{model.connection.columns(table_name).inspect}"

          primary_key_found = false
          index_definitions = model.connection.indexes(table_name).map do |i|
            model.ignore_indexes.include?(i.name) and next
            if i.name == PRIMARY_KEY_NAME
              i.columns == primary_key_columns && i.unique or
                raise "primary key on #{table_name} was not unique on #{primary_key_columns} (was unique=#{i.unique} on #{i.columns})"
              primary_key_found = true
            end
            new(table_name, i.columns, name: i.name, unique: i.unique, where: i.where)
          end.compact

          if !primary_key_found
            index_definitions << new(table_name, primary_key_columns, name: PRIMARY_KEY_NAME, unique: true, where: nil)
          end
          index_definitions
        end

        def default_index_name(table_name, fields)
          index_name = nil
          [:long_index_name, :short_index_name].find do |method_name|
            index_name = send(method_name, table_name, fields)
            if DeclareSchema.max_index_and_constraint_name_length.nil? || index_name.length <= DeclareSchema.max_index_and_constraint_name_length
              break index_name
            end
          end or raise IndexNameTooLongError,
                       "Default index name '#{index_name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters. Use the `name:` option to give it a shorter name, or adjust DeclareSchema.max_index_and_constraint_name_length if you know your database can accept longer names."
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

      def to_key
        @to_key ||= [table_name, fields, name, unique, where].map(&:to_s)
      end

      def settings
        @settings ||= [table_name, fields, unique].map(&:to_s)
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
        self.class.new(@table_name, @fields, table_name: @table_name, index_name: @index_name, unique: @unique, name: new_name)
      end

      alias eql? ==
    end
  end
end
