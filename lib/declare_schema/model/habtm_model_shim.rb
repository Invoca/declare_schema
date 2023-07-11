# frozen_string_literal: true

module DeclareSchema
  module Model
    class HabtmModelShim
      class << self
        def from_reflection(refl)
          new(refl.join_table, [refl.foreign_key, refl.association_foreign_key],
                               [refl.active_record.table_name, refl.class_name.constantize.table_name])
        end
      end

      attr_reader :join_table, :foreign_keys, :table_names

      def initialize(join_table, foreign_keys, table_names)
        foreign_keys.is_a?(Array) && foreign_keys.size == 2 or
          raise ArgumentError, "foreign_keys must be <Array[2]>; got #{foreign_keys.inspect}"
        table_names.is_a?(Array) && table_names.size == 2 or
          raise ArgumentError, "table_names must be <Array[2]>; got #{table_names.inspect}"
        @join_table = join_table
        @foreign_keys = foreign_keys.sort
        @table_names = @foreign_keys == foreign_keys ? table_names : table_names.reverse
      end

      def _table_options
        {}
      end

      def table_name
        join_table
      end

      def field_specs
        foreign_keys.each_with_index.each_with_object({}) do |(foreign_key, i), result|
          result[foreign_key] = ::DeclareSchema::Model::FieldSpec.new(self, foreign_key, :bigint, position: i, null: false)
        end
      end

      def primary_key
        false # no single-column primary key in database
      end

      def _declared_primary_key
        false # no single-column primary key declared
      end

      def index_definitions_with_primary_key
        [
          IndexDefinition.new(table_name, foreign_keys, unique: true, name: Model::IndexDefinition::PRIMARY_KEY_NAME), # creates a primary composite key on both foreign keys
          IndexDefinition.new(table_name, foreign_keys.last) # not unique by itself; combines with primary key to be unique
        ]
      end

      alias_method :index_definitions, :index_definitions_with_primary_key

      def ignore_indexes
        []
      end

      def constraint_specs
        [
          ForeignKeyDefinition.new(self, foreign_keys.first, parent_table: table_names.first, constraint_name: "#{join_table}_FK1", dependent: :delete),
          ForeignKeyDefinition.new(self, foreign_keys.last, parent_table: table_names.last, constraint_name: "#{join_table}_FK2", dependent: :delete)
        ]
      end
    end
  end
end
