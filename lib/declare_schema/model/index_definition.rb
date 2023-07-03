# frozen_string_literal: true

module DeclareSchema
  module Model
    class IndexDefinition
      include Comparable

      # TODO: replace `fields` with `columns` and remove alias. -Colin
      attr_reader :table, :fields, :explicit_name, :name, :unique, :where
      alias columns fields

      class IndexNameTooLongError < RuntimeError; end

      PRIMARY_KEY_NAME = "PRIMARY"

      def initialize(model, fields, **options)
        @model = model
        @table = options.delete(:table_name) || model.table_name
        @fields = Array.wrap(fields).map(&:to_s)
        @explicit_name = options[:name] unless options.delete(:allow_equivalent)
        @name = options.delete(:name) || self.class.default_index_name(@table, @fields)
        @unique = options.delete(:unique) || name == PRIMARY_KEY_NAME || false

        if DeclareSchema.max_index_and_constraint_name_length && @name.length > DeclareSchema.max_index_and_constraint_name_length
          raise IndexNameTooLongError, "Index '#{@name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters. Give it a shorter name, or adjust DeclareSchema.max_index_and_constraint_name_length if you know your database can accept longer names."
        end

        if (where = options[:where])
          @where = where.start_with?('(') ? where : "(#{where})"
        end
      end

      class << self
        # extract IndexSpecs from an existing table
        # includes the PRIMARY KEY index
        def for_model(model, old_table_name = nil)
          t = old_table_name || model.table_name

          primary_key_columns = Array(model.connection.primary_key(t)).presence
          primary_key_columns or raise "could not find primary key for table #{t} in #{model.connection.columns(t).inspect}"

          primary_key_found = false
          index_definitions = model.connection.indexes(t).map do |i|
            model.ignore_indexes.include?(i.name) and next
            if i.name == PRIMARY_KEY_NAME
              i.columns == primary_key_columns && i.unique or
                raise "primary key on #{t} was not unique on #{primary_key_columns} (was unique=#{i.unique} on #{i.columns})"
              primary_key_found = true
            end
            new(model, i.columns, name: i.name, unique: i.unique, where: i.where, table_name: old_table_name)
          end.compact

          if !primary_key_found
            index_definitions << new(model, primary_key_columns, name: PRIMARY_KEY_NAME, unique: true, where: nil, table_name: old_table_name)
          end
          index_definitions
        end

        def default_index_name(table, fields)
          index_name = nil
          [:long_index_name, :short_index_name].find do |method_name|
            index_name = send(method_name, table, fields)
            if DeclareSchema.max_index_and_constraint_name_length.nil? || index_name.length <= DeclareSchema.max_index_and_constraint_name_length
              break index_name
            end
          end or raise IndexNameTooLongError,
                       "Index '#{index_name}' exceeds configured limit of #{DeclareSchema.max_index_and_constraint_name_length} characters."
        end

        private

        def long_index_name(table_name, columns)
          "index_#{table_name}_on_#{Array(columns).join("_and_")}"
        end

        def short_index_name(table_name, columns)
          "#{table_name}__#{Array(columns).join("_")}"
        end
      end

      def primary_key?
        name == PRIMARY_KEY_NAME
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
