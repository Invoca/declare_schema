# frozen_string_literal: true

module DeclareSchema
  module Model
    class ForeignKeyDefinition
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
          if (klass = options[:class_name])
            klass = klass.to_s.constantize unless klass.is_a?(Class)
            klass.try(:table_name)
          end || foreign_key.sub(/_id\z/, '').camelize.constantize.table_name
      end

      attr_writer :parent_table_name

      def to_add_statement(_new_table_name = nil, _existing_primary_key = nil)
        statement = "ALTER TABLE #{@child_table} ADD CONSTRAINT #{@constraint_name} FOREIGN KEY #{@index_name}(#{@foreign_key_name}) REFERENCES #{parent_table_name}(id) #{'ON DELETE CASCADE' if on_delete_cascade}"
        "execute #{statement.inspect}"
      end

      def key
        @key ||= [@child_table, parent_table_name, @foreign_key_name, @on_delete_cascade].map(&:to_s)
      end

      def hash
        key.hash
      end

      def <=>(rhs)
        key <=> rhs.key
      end

      alias eql? ==
    end
  end
end
