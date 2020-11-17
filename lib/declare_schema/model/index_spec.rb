# frozen_string_literal: true

module DeclareSchema
  module Model
    class IndexSpec
      include Comparable

      attr_reader :table, :fields, :explicit_name, :name, :unique, :where

      class IndexNameTooLongError < RuntimeError; end

      PRIMARY_KEY_NAME = "PRIMARY_KEY"
      MYSQL_INDEX_NAME_MAX_LENGTH = 64

      def initialize(model, fields, options = {})
        @model = model
        @table = options.delete(:table_name) || model.table_name
        @fields = Array.wrap(fields).map(&:to_s)
        @explicit_name = options[:name] unless options.delete(:allow_equivalent)
        @name = options.delete(:name) || model.connection.index_name(table, column: @fields).gsub(/index.*_on_/, 'on_')
        @unique = options.delete(:unique) || name == PRIMARY_KEY_NAME || false

        if @name.length > MYSQL_INDEX_NAME_MAX_LENGTH
          raise IndexNameTooLongError, "Index '#{@name}' exceeds MySQL limit of #{MYSQL_INDEX_NAME_MAX_LENGTH} characters. Give it a shorter name."
        end

        if (where = options[:where])
          @where = where.start_with?('(') ? where : "(#{where})"
        end
      end

      class << self
        # extract IndexSpecs from an existing table
        def for_model(model, old_table_name = nil)
          t = old_table_name || model.table_name
          connection = model.connection.dup
          # TODO: Change below to use prepend
          class << connection              # defeat Rails code that skips the primary keys by changing their name to PRIMARY_KEY_NAME
            def each_hash(result)
              super do |hash|
                if hash[:Key_name] == "PRIMARY"
                  hash[:Key_name] = PRIMARY_KEY_NAME
                end
                yield hash
              end
            end
          end
          connection.indexes(t).map do |i|
            new(model, i.columns, name: i.name, unique: i.unique, where: i.where, table_name: old_table_name) unless model.ignore_indexes.include?(i.name)
          end.compact
        end
      end

      def primary_key?
        name == PRIMARY_KEY_NAME
      end

      def to_add_statement(new_table_name, existing_primary_key = nil)
        if primary_key? && !ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
          to_add_primary_key_statement(new_table_name, existing_primary_key)
        else
          r = +"add_index #{new_table_name.to_sym.inspect}, #{fields.map(&:to_sym).inspect}"
          r += ", unique: true"      if unique
          r += ", where: '#{where}'" if where.present?
          r += ", name: '#{name}'"
          r
        end
      end

      def to_add_primary_key_statement(new_table_name, existing_primary_key)
        drop = "DROP PRIMARY KEY, " if existing_primary_key
        statement = "ALTER TABLE #{new_table_name} #{drop}ADD PRIMARY KEY (#{fields.join(', ')})"
        "execute #{statement.inspect}"
      end

      def to_key
        @key ||= [table, fields, name, unique, where].map(&:to_s)
      end

      def settings
        @settings ||= [table, fields, unique].map(&:to_s)
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
        self.class.new(@model, @fields, table_name: @table_name, index_name: @index_name, unique: @unique, name: new_name)
      end

      alias eql? ==
    end
  end
end
