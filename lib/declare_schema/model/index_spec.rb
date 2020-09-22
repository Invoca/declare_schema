# frozen_string_literal: true

module DeclareSchema
  module Model
    class IndexSpec
      include Comparable

      attr_accessor :table, :fields, :explicit_name, :name, :unique, :where

      class IndexNameTooLongError < RuntimeError; end

      PRIMARY_KEY_NAME = "PRIMARY_KEY"
      MYSQL_INDEX_NAME_MAX_LENGTH = 64

      def initialize(model, fields, options = {})
        @model = model
        self.table = options.delete(:table_name) || model.table_name
        self.fields = Array.wrap(fields).map(&:to_s)
        self.explicit_name = options[:name] unless options.delete(:allow_equivalent)
        self.name = options.delete(:name) || model.connection.index_name(table, column: self.fields).gsub(/index.*_on_/, 'on_')
        self.unique = options.delete(:unique) || name == PRIMARY_KEY_NAME || false

        if name.length > MYSQL_INDEX_NAME_MAX_LENGTH
          raise IndexNameTooLongError, "Index '#{name}' exceeds MySQL limit of #{MYSQL_INDEX_NAME_MAX_LENGTH} characters. Give it a shorter name."
        end

        if (where = options[:where])
          self.where = where.start_with?('(') ? where : "(#{where})"
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

    class ForeignKeySpec
      include Comparable

      attr_reader :constraint_name, :model, :foreign_key, :options, :on_delete_cascade

      def initialize(model, foreign_key, options = {})
        @model = model
        @foreign_key = foreign_key.presence
        @options = options

        @child_table = model.table_name # unless a table rename, which would happen when a class is renamed??
        @parent_table_name = options[:parent_table]
        @foreign_key_name = options[:foreign_key] || self.foreign_key
        @index_name = options[:index_name] || model.connection.index_name(model.table_name, column: foreign_key)
        @constraint_name = options[:constraint_name] || @index_name || ''
        @on_delete_cascade = options[:dependent] == :delete

        # Empty constraint lets mysql generate the name
      end

      class << self
        def for_model(model, old_table_name)
          show_create_table = model.connection.select_rows("show create table #{model.connection.quote_table_name(old_table_name)}").first.last
          constraints = show_create_table.split("\n").map { |line| line.strip if line['CONSTRAINT'] }.compact

          constraints.map do |fkc|
            options = {}
            name, foreign_key, parent_table = fkc.match(/CONSTRAINT `([^`]*)` FOREIGN KEY \(`([^`]*)`\) REFERENCES `([^`]*)`/).captures
            options[:constraint_name] = name
            options[:parent_table] = parent_table
            options[:foreign_key] = foreign_key
            options[:dependent] = :delete if fkc['ON DELETE CASCADE']

            new(model, foreign_key, options)
          end
        end
      end

      def parent_table_name
        @parent_table_name ||=
          options[:class_name]&.is_a?(Class) &&
          options[:class_name].respond_to?(:table_name) &&
          options[:class_name]&.table_name
        @parent_table_name ||=
          options[:class_name]&.constantize &&
          options[:class_name].constantize.respond_to?(:table_name) &&
          options[:class_name].constantize.table_name ||
          foreign_key.gsub(/_id/, '').camelize.constantize.table_name
      end

      attr_writer :parent_table_name

      def to_add_statement(_ = true)
        statement = "ALTER TABLE #{@child_table} ADD CONSTRAINT #{@constraint_name} FOREIGN KEY #{@index_name}(#{@foreign_key_name}) REFERENCES #{parent_table_name}(id) #{'ON DELETE CASCADE' if on_delete_cascade}"
        "execute #{statement.inspect}"
      end

      def to_key
        @key ||= [@child_table, parent_table_name, @foreign_key_name, @on_delete_cascade].map(&:to_s)
      end

      def hash
        to_key.hash
      end

      def <=>(rhs)
        to_key <=> rhs.to_key
      end

      alias eql? ==
    end
  end
end
