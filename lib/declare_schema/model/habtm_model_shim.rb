# frozen_string_literal: true

module DeclareSchema
  module Model
    class HabtmModelShim
      class << self
        def from_reflection(refl)
          join_table = refl.join_table
          foreign_keys_and_classes = [
            [refl.foreign_key.to_s, refl.active_record],
            [refl.association_foreign_key.to_s, refl.class_name.constantize]
          ].sort { |a, b| a.first <=> b.first }
          foreign_keys = foreign_keys_and_classes.map(&:first)
          foreign_key_classes = foreign_keys_and_classes.map(&:last)
          # this may fail in weird ways if HABTM is running across two DB connections (assuming that's even supported)
          # figure that anybody who sets THAT up can deal with their own migrations...
          connection = refl.active_record.connection

          new(join_table, foreign_keys, foreign_key_classes, connection)
        end
      end

      attr_reader :join_table, :foreign_keys, :foreign_key_classes, :connection

      def initialize(join_table, foreign_keys, foreign_key_classes, connection)
        @join_table = join_table
        @foreign_keys = foreign_keys
        @foreign_key_classes = foreign_key_classes
        @connection = connection
      end

      def _table_options
        {}
      end

      def table_name
        join_table
      end

      def index_name
        "index_#{table_name}_on_#{foreign_keys.first}_#{foreign_keys.last}"
      end

      def field_specs
        foreign_keys.each_with_index.each_with_object({}) do |(v, position), result|
          result[v] = ::DeclareSchema::Model::FieldSpec.new(self, v, :bigint, position: position, null: false)
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
          IndexDefinition.new(self, foreign_keys, unique: true, name: index_name) # creates a primary composite key on both foriegn keys
        ]
      end

      alias_method :index_definitions, :index_definitions_with_primary_key

      def ignore_indexes
        []
      end

      def constraint_specs
        [
          ForeignKeyDefinition.new(self, foreign_keys.first, parent_table: foreign_key_classes.first.table_name, constraint_name: "#{join_table}_FK1", dependent: :delete),
          ForeignKeyDefinition.new(self, foreign_keys.last, parent_table: foreign_key_classes.last.table_name, constraint_name: "#{join_table}_FK2", dependent: :delete)
        ]
      end
    end
  end
end
