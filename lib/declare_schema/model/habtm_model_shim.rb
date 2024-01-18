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

      attr_reader :join_table, :foreign_keys, :parent_table_names

      def initialize(join_table, foreign_keys, parent_table_names)
        foreign_keys.is_a?(Array) && foreign_keys.size == 2 or
          raise ArgumentError, "foreign_keys must be <Array[2]>; got #{foreign_keys.inspect}"
        parent_table_names.is_a?(Array) && parent_table_names.size == 2 or
          raise ArgumentError, "parent_table_names must be <Array[2]>; got #{parent_table_names.inspect}"
        @join_table = join_table
        @foreign_keys = foreign_keys.sort # Rails requires these be in alphabetical order
        @parent_table_names = @foreign_keys == foreign_keys ? parent_table_names : parent_table_names.reverse # match the above sort
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
        @index_definitions_with_primary_key ||= Set.new([
          IndexDefinition.new(foreign_keys, name: Model::IndexDefinition::PRIMARY_KEY_NAME, table_name: table_name, unique: true), # creates a primary composite key on both foreign keys
          IndexDefinition.new(foreign_keys.last,                                            table_name: table_name, unique: false) # index for queries where we only have the last foreign key
        ])
      end

      alias_method :index_definitions, :index_definitions_with_primary_key

      def ignore_indexes
        @ignore_indexes ||= Set.new
      end

      def constraint_definitions
        @constraint_definitions ||= Set.new([
          ForeignKeyDefinition.new(foreign_keys.first, constraint_name: "#{join_table}_FK1", child_table_name: @join_table, parent_table_name: parent_table_names.first, dependent: :delete),
          ForeignKeyDefinition.new(foreign_keys.last, constraint_name: "#{join_table}_FK2", child_table_name: @join_table, parent_table_name: parent_table_names.last, dependent: :delete)
        ])
      end
    end
  end
end
