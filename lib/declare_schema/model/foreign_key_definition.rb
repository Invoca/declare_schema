# frozen_string_literal: true

require_relative 'index_definition'

module DeclareSchema
  module Model
    class ForeignKeyDefinition
      include Comparable

      attr_reader :constraint_name, :model, :foreign_key, :foreign_key_name, :child_table_name, :options, :on_delete_cascade


      def initialize(model, foreign_key, **options)
        @model = model
        @foreign_key = foreign_key.to_s.presence or raise ArgumentError "Foreign key must not be empty: #{foreign_key.inspect}"
        @options = options

        @child_table_name = model.table_name # unless a table rename, which would happen when a class is renamed??
        @parent_table_name = options[:parent_table]&.to_s
        @foreign_key_name = options[:foreign_key]&.to_s || @foreign_key

        @parent_class_name =
          case class_name = options[:class_name]
          when String, Symbol
            class_name.to_s
          when Class
            @parent_class = class_name
            @parent_class.name
          when nil
            @foreign_key.sub(/_id\z/, '').camelize
          end

        @constraint_name = options[:constraint_name]&.to_s.presence ||
                             model.connection.index_name(model.table_name, column: @foreign_key_name)
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
            options[:dependent] = :delete if fkc['ON DELETE CASCADE'] || model.is_a?(DeclareSchema::Model::HabtmModelShim)

            new(model, foreign_key, **options)
          end
        end
      end

      # returns the parent class as a Class object
      # lazy loaded so that we don't require the parent class until we need it
      def parent_class
        @parent_class ||= @parent_class_name.constantize
      end

      def parent_table_name
        @parent_table_name ||= parent_class.table_name
      end

      def <=>(rhs)
        key <=> rhs.send(:key)
      end

      alias eql? ==

      def hash
        key.hash
      end

      private

      def key
        @key ||= [@child_table_name, @parent_class_name, @foreign_key_name, @on_delete_cascade].map(&:to_s)
      end
    end
  end
end
