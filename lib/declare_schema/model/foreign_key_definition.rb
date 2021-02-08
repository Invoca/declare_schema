# frozen_string_literal: true

module DeclareSchema
  module Model
    class ForeignKeyDefinition
      include Comparable

      attr_reader :constraint_name, :model, :foreign_key, :foreign_key_name, :options, :on_delete_cascade

      def initialize(model, foreign_key, options = {})
        @model = model
        @foreign_key = foreign_key.to_s.presence
        @options = options

        @child_table = model.table_name # unless a table rename, which would happen when a class is renamed??
        @parent_table_name = options[:parent_table]&.to_s
        @foreign_key_name = options[:foreign_key]&.to_s || @foreign_key
        @index_name = options[:index_name]&.to_s || model.connection.index_name(model.table_name, column: @foreign_key_name)

        # Empty constraint lets mysql generate the name
        @constraint_name = options[:constraint_name]&.to_s || @index_name&.to_s || ''
        @on_delete_cascade = options[:dependent] == :delete
      end

      class << self
        def for_model(model, old_table_name)
          show_create_table = model.connection.select_rows("show create table #{model.connection.quote_table_name(old_table_name)}").first.last
          constraints = show_create_table.split("\n").map { |line| line.strip if line['CONSTRAINT'] }.compact

          constraints.map do |fkc|
            name, foreign_key, parent_table = fkc.match(/CONSTRAINT `([^`]*)` FOREIGN KEY \(`([^`]*)`\) REFERENCES `([^`]*)`/).captures
            options = {
              constraint_name: name,
              parent_table:    parent_table,
              foreign_key:     foreign_key
            }
            options[:dependent] = :delete if fkc['ON DELETE CASCADE']

            new(model, foreign_key, options)
          end
        end
      end

      # returns the parent class as a Class object
      # or nil if no :class_name option given
      def parent_class
        if (class_name = options[:class_name])
          if class_name.is_a?(Class)
            class_name
          else
            class_name.to_s.constantize
          end
        end
      end

      def parent_table_name
        @parent_table_name ||=
          parent_class&.try(:table_name) ||
            foreign_key.sub(/_id\z/, '').camelize.constantize.table_name
      end

      def to_add_statement
        "add_foreign_key(#{@child_table.inspect}, #{parent_table_name.inspect}, " +
          "column: #{@foreign_key_name.inspect}, name: #{@constraint_name.inspect})"
      end

      def <=>(rhs)
        key <=> rhs.send(:key)
      end

      alias eql? ==

      private

      def key
        @key ||= [@child_table, parent_table_name, @foreign_key_name, @on_delete_cascade].map(&:to_s)
      end

      def hash
        key.hash
      end
    end
  end
end
