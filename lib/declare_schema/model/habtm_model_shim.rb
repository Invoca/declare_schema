# frozen_string_literal: true

module DeclareSchema
  module Model
    class HabtmModelShim
      class << self
        def from_reflection(reflection)
          new(reflection.join_table,
              [
                [reflection.foreign_key, reflection.active_record],
                [reflection.association_foreign_key, reflection.klass]
              ],
              connection: reflection.active_record.connection)
        end
      end

      attr_reader :join_table, :foreign_keys, :parent_models, :parent_table_names, :connection

      def initialize(join_table, parents, connection:)
        @join_table = join_table

        parents.is_a?(Array) && parents.size == 2 or
          raise ArgumentError, "parents must be <Array[2]>; got #{parents.inspect}"

        # Rails requires foreign keys to be in alphabetical order, so we start by sorting by those
        parents.sort_by!(&:first)
        @foreign_keys = parents.map(&:first)
        @parent_models = parents.map(&:last)
        @parent_table_names = parent_models.map(&:table_name)

        @connection = connection
      end

      def _table_options
        {}
      end

      def table_name
        join_table
      end

      def field_specs
        foreign_keys.each_with_index.each_with_object({}) do |(foreign_key, i), result|
          pk_field_spec = parent_models[i]._primary_key_field_spec
          result[foreign_key] = pk_field_spec.foreign_key_field_spec(self, foreign_key, position: i, null: false)
        end
      end

      def primary_key
        false # no single-column primary key in database
      end

      def _declared_primary_key
        foreign_keys
      end

      def index_definitions
        [
          IndexDefinition.new(foreign_keys.last, table_name: table_name, unique: false) # index for queries where we only have the last foreign key
        ]
      end

      def index_definitions_with_primary_key
        [
          *index_definitions,
          IndexDefinition.new(foreign_keys, table_name: table_name, name: Model::IndexDefinition::PRIMARY_KEY_NAME, unique: true) # creates a primary composite key on both foreign keys
        ]
      end

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
