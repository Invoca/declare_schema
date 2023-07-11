# frozen_string_literal: true

require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'
require 'declare_schema/schema_change/all'

module Generators
  module DeclareSchema
    module Migration
      class Migrator
        class Error < RuntimeError; end

        @ignore_models                        = []
        @ignore_tables                        = []
        @before_generating_migration_callback = nil
        @active_record_class                  = ActiveRecord::Base

        class << self
          attr_accessor :ignore_models, :ignore_tables
          attr_reader :active_record_class, :before_generating_migration_callback

          def active_record_class
            @active_record_class.is_a?(Class) or @active_record_class = @active_record_class.to_s.constantize
            @active_record_class
          end

          def run(**renames)
            Migrator.new(renames: renames).generate
          end

          def default_migration_name(existing_migrations = Dir["#{Rails.root}/db/migrate/*declare_schema_migration*"])
            max = existing_migrations.grep(/([0-9]+)\.rb$/) { Regexp.last_match(1).to_i }.max.to_i
            "declare_schema_migration_#{max + 1}"
          end

          def connection
            ActiveRecord::Base.connection
          end

          def before_generating_migration(&block)
            block or raise ArgumentError, 'A block is required when setting the before_generating_migration callback'
            @before_generating_migration_callback = block
          end

          delegate :default_charset=, :default_collation=, :default_charset, :default_collation, to: ::DeclareSchema
          deprecate :default_charset=, :default_collation=, :default_charset, :default_collation, deprecator: ActiveSupport::Deprecation.new('1.0', 'declare_schema')
        end

        def initialize(renames: nil, &block)
          @ambiguity_resolver = block
          @drops = []
          @renames = renames
        end

        def load_rails_models
          ActiveRecord::Migration.verbose = false
          if defined?(Rails)
            Rails.application or raise "Rails is defined, so Rails.application must be set"
            Rails.application.eager_load!
            Rails::Engine.subclasses.each(&:eager_load!)
          end
          self.class.before_generating_migration_callback&.call
        end

        # Returns an array of model classes that *directly* extend
        # ActiveRecord::Base, excluding anything in the CGI module
        def table_model_classes
          load_rails_models
          ActiveRecord::Base.send(:descendants).select do |klass|
            klass.base_class == klass && !klass.name.starts_with?("CGI::")
          end
        end

        def connection
          self.class.connection
        end

        def native_types
          self.class.native_types
        end

        # list habtm join tables
        def habtm_tables
          reflections = Hash.new { |h, k| h[k] = [] }
          ActiveRecord::Base.send(:descendants).map do |c|
            c.reflect_on_all_associations(:has_and_belongs_to_many).each do |a|
              reflections[a.join_table] << a
            end
          end
          reflections
        end

        # Returns an array of model classes and an array of table names
        # that generation needs to take into account
        def models_and_tables
          ignore_model_names = Migrator.ignore_models.map { |model| model.to_s.underscore }
          all_models = table_model_classes
          declare_schema_models = all_models.select do |m|
            (m.name['HABTM_'] ||
              (m.include_in_migration if m.respond_to?(:include_in_migration))) && !m.name.underscore.in?(ignore_model_names)
          end
          non_declare_schema_models = all_models - declare_schema_models
          db_tables = connection.tables - Migrator.ignore_tables.map(&:to_s) - non_declare_schema_models.map(&:table_name)
          [declare_schema_models, db_tables]
        end

        # return a hash of table renames and modifies the passed arrays so
        # that renamed tables are no longer listed as to_create or to_drop
        def extract_table_renames!(to_create, to_drop)
          if @renames
            # A hash of table renames has been provided

            to_rename = {}
            @renames.each do |old_name, new_name|
              if new_name.is_a?(Hash)
                new_name = new_name[:table_name]
              end
              new_name or next

              old_name = old_name.to_s
              new_name = new_name.to_s

              to_create.delete(new_name) or raise Error,
                "Rename specified new name: #{new_name.inspect} but it was not in the `to_create` list"
              to_drop.delete(old_name) or raise Error,
                "Rename specified old name: #{old_name.inspect} but it was not in the `to_drop` list"
              to_rename[old_name] = new_name
            end
            to_rename

          elsif @ambiguity_resolver
            @ambiguity_resolver.call(to_create, to_drop, "table", nil)

          else
            raise Error, "Unable to resolve migration ambiguities"
          end
        end

        # return a hash of column renames and modifies the passed arrays so
        # that renamed columns are no longer listed as to_create or to_drop
        def extract_column_renames!(to_add, to_remove, table_name)
          if @renames
            to_rename = {}
            if (column_renames = @renames[table_name.to_sym])
              # A hash of column renames has been provided

              column_renames.each do |old_name, new_name|
                old_name = old_name.to_s
                new_name = new_name.to_s
                to_add.delete(new_name) or raise Error,
                  "Rename specified new name: #{new_name.inspect} but it was not in the `to_add` list for table #{table_name}"
                to_remove.delete(old_name) or raise Error,
                  "Rename specified old name: #{old_name.inspect} but it was not in the `to_remove` list for table #{table_name}"
                to_rename[old_name] = new_name
              end
            end
            to_rename

          elsif @ambiguity_resolver
            @ambiguity_resolver.call(to_add, to_remove, "column", "#{table_name}.")

          else
            raise Error, "Unable to resolve migration ambiguities in table #{table_name}"
          end
        end

        def self.always_ignore_tables
          sessions_table =
            begin
              if defined?(CGI::Session::ActiveRecordStore::Session) &&
                 defined?(ActionController::Base) &&
                 ActionController::Base.session_store == CGI::Session::ActiveRecordStore
                CGI::Session::ActiveRecordStore::Session.table_name
              end
            rescue
              nil
            end

          [
            'schema_info',
            ActiveRecord::Base.try(:schema_migrations_table_name) || 'schema_migrations',
            ActiveRecord::Base.try(:internal_metadata_table_name) || 'ar_internal_metadata',
            sessions_table
          ].compact
        end

        def generate
          models, db_tables = models_and_tables
          models_by_table_name = {}
          models.each do |m|
            m.try(:field_specs)&.each do |_name, field_spec|
              if (pre_migration = field_spec.options.delete(:pre_migration))
                pre_migration.call(field_spec)
              end
            end

            if !models_by_table_name.has_key?(m.table_name)
              models_by_table_name[m.table_name] = m
            elsif m.superclass == models_by_table_name[m.table_name].superclass.superclass
              # we need to ensure that models_by_table_name contains the
              # base class in an STI hierarchy
              models_by_table_name[m.table_name] = m
            end
          end
          # generate shims for HABTM models
          habtm_tables.each do |name, refls|
            models_by_table_name[name] = ::DeclareSchema::Model::HabtmModelShim.from_reflection(refls.first)
          end
          model_table_names = models_by_table_name.keys

          to_create = model_table_names - db_tables
          to_drop = db_tables - model_table_names - self.class.always_ignore_tables
          to_rename = extract_table_renames!(to_create, to_drop)
          to_change = model_table_names

          renames = to_rename.map do |old_name, new_name|
            ::DeclareSchema::SchemaChange::TableRename.new(old_name, new_name)
          end

          drops = to_drop.map do |t|
            ::DeclareSchema::SchemaChange::TableRemove.new(t, add_table_back(t))
          end

          creates = to_create.map do |t|
            model = models_by_table_name[t]
            disable_auto_increment = model.try(:disable_auto_increment)

            primary_key_definition =
              if disable_auto_increment
                [[:integer, :id, limit: 8, auto_increment: false, primary_key: true]]
              else
                []
              end

            field_definitions = model.field_specs.values.sort_by(&:position).map do |f|
              [f.type, f.name, f.sql_options]
            end

            table_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.new(model.table_name, **table_options_for_model(model))
            table_options = create_table_options(model, disable_auto_increment)

            table_add = ::DeclareSchema::SchemaChange::TableAdd.new(t,
                                                                    primary_key_definition + field_definitions,
                                                                    table_options,
                                                                    sql_options: table_options_definition.settings)
            [
              table_add,
              *Array((create_indexes(model)     if ::DeclareSchema.default_generate_indexing)),
              *Array((create_constraints(model) if ::DeclareSchema.default_generate_foreign_keys))
            ]
          end

          changes                    = []
          index_changes              = []
          fk_changes                 = []
          table_options_changes      = []

          to_change.each do |t|
            model = models_by_table_name[t]
            table = to_rename.key(t) || model.table_name
            if table.in?(db_tables)
              change, index_change, fk_change, table_options_change = change_table(model, table)
              changes << change
              index_changes << index_change
              fk_changes << fk_change
              table_options_changes << table_options_change
            end
          end

          migration_commands = [renames, drops, creates, changes, index_changes, fk_changes, table_options_changes].flatten

          ordered_migration_commands = order_migrations(migration_commands)

          up_and_down_migrations(ordered_migration_commands)
        end

        MIGRATION_ORDER = %w[ TableRename
                              TableAdd
                              TableChange
                                ColumnAdd
                                ColumnRename
                                ColumnChange
                                  PrimaryKeyChange
                                  IndexAdd
                                    ForeignKeyAdd
                                    ForeignKeyRemove
                                  IndexRemove
                                ColumnRemove
                              TableRemove ]

        def order_migrations(migration_commands)
          migration_commands.each_with_index.sort_by do |command, index|
            command_type = command.class.name.gsub(/.*::/, '')
            priority = MIGRATION_ORDER.index(command_type) or raise "#{command_type.inspect} not found in #{MIGRATION_ORDER.inspect}"
            [priority, index] # index keeps the sort stable in case of a tie
          end.map(&:first) # remove the index
        end

        private

        def up_and_down_migrations(migration_commands)
          up   = migration_commands.map(&:up  ).select(&:present?)
          down = migration_commands.map(&:down).select(&:present?).reverse

          [up * "\n", down * "\n"]
        end

        def create_table_options(model, disable_auto_increment)
          primary_key = model._declared_primary_key
          if primary_key.blank? || disable_auto_increment
            { id: false }
          elsif primary_key == "id"
            { id: :bigint }
          else
            { primary_key: primary_key.to_sym }
          end.merge(model._table_options)
        end

        def table_options_for_model(model)
          if ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
            {}
          else
            {
              charset:   model._table_options&.[](:charset) || ::DeclareSchema.default_charset,
              collation: model._table_options&.[](:collation) || ::DeclareSchema.default_collation
            }
          end
        end

        # TODO: TECH-5338: optimize that index doesn't need to be dropped on undo since entire table will be dropped
        def create_indexes(model)
          model.index_definitions.map do |i|
            ::DeclareSchema::SchemaChange::IndexAdd.new(model.table_name, i.columns, unique: i.unique, where: i.where, name: i.name)
          end
        end

        def create_constraints(model)
          model.constraint_specs.map do |fk|
            ::DeclareSchema::SchemaChange::ForeignKeyAdd.new(fk.child_table_name, fk.parent_table_name,
                                                             column_name: fk.foreign_key_name, name: fk.constraint_name)
          end
        end

        def change_table(model, current_table_name)
          new_table_name = model.table_name

          db_columns = model.connection.columns(current_table_name).index_by(&:name)
          if (pk = model._declared_primary_key.presence)
            pk_was_in_db_columns = db_columns.delete(pk)
          end

          model_column_names = model.field_specs.keys.map(&:to_s)
          db_column_names = db_columns.keys.map(&:to_s)

          to_add = model_column_names - db_column_names
          to_add << pk if pk && !pk_was_in_db_columns
          to_remove = db_column_names - model_column_names

          to_rename = extract_column_renames!(to_add, to_remove, new_table_name)

          db_column_names -= to_rename.keys
          db_column_names |= to_rename.values
          to_change = db_column_names & model_column_names

          renames = to_rename.map do |old_name, new_name|
            ::DeclareSchema::SchemaChange::ColumnRename.new(new_table_name, old_name, new_name)
          end

          to_add.sort_by! { |c| model.field_specs[c]&.position || 0 }

          adds = to_add.map do |c|
            type, options =
              if (spec = model.field_specs[c])
                [spec.type, spec.sql_options.merge(fk_field_options(model, c)).compact]
              else
                [:integer, {}]
              end
            ::DeclareSchema::SchemaChange::ColumnAdd.new(new_table_name, c, type, **options)
          end

          removes = to_remove.map do |c|
            old_type, old_options = add_column_back(model, current_table_name, c)
            ::DeclareSchema::SchemaChange::ColumnRemove.new(new_table_name, c, old_type, **old_options)
          end

          old_names = to_rename.invert
          changes = []
          to_change.each do |col_name_to_change|
            orig_col_name      = old_names[col_name_to_change] || col_name_to_change
            column             = db_columns[orig_col_name] or raise "failed to find column info for #{orig_col_name.inspect}"
            spec               = model.field_specs[col_name_to_change] or raise "failed to find field spec for #{col_name_to_change.inspect}"
            spec_attrs         = spec.schema_attributes(column)
            column_declaration = ::DeclareSchema::Model::Column.new(model, current_table_name, column)
            col_attrs          = column_declaration.schema_attributes
            normalized_schema_attrs = spec_attrs.merge(fk_field_options(model, col_name_to_change))

            if !::DeclareSchema::Model::Column.equivalent_schema_attributes?(normalized_schema_attrs, col_attrs)
              type = normalized_schema_attrs.delete(:type) or raise "no :type found in #{normalized_schema_attrs.inspect}"
              old_type, old_options = change_column_back(model, current_table_name, orig_col_name)
              changes << ::DeclareSchema::SchemaChange::ColumnChange.new(new_table_name, col_name_to_change,
                                                                         new_type: type, new_options: normalized_schema_attrs,
                                                                         old_type: old_type, old_options: old_options)
            end
          end

          index_changes = change_indexes(model, current_table_name, to_rename)
          fk_changes = if ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
                         []
                       else
                         change_foreign_key_constraints(model, current_table_name, to_rename)
                       end
          table_options_changes = if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
                                    change_table_options(model, current_table_name)
                                  else
                                    []
                                  end

          [(renames + adds + removes + changes),
           index_changes,
           fk_changes,
           table_options_changes]
        end

        def change_indexes(model, old_table_name, to_rename)
          ::DeclareSchema.default_generate_indexing or return []

          new_table_name = model.table_name
          existing_indexes = ::DeclareSchema::Model::IndexDefinition.for_model(model, old_table_name)
          model_indexes_with_equivalents = model.index_definitions_with_primary_key
          model_indexes = model_indexes_with_equivalents.map do |i|
            if i.explicit_name.nil?
              if (existing = existing_indexes.find { |e| i != e && e.equivalent?(i) })
                i.with_name(existing.name)
              end
            end || i
          end
          existing_primary_keys, existing_indexes_without_primary_key = existing_indexes.partition { |i| i.primary_key? }
          defined_primary_keys, model_indexes_without_primary_key = model_indexes.partition { |i| i.primary_key? }
          existing_primary_keys.size <= 1 or raise "too many existing primary keys! #{existing_primary_keys.inspect}"
          defined_primary_keys.size <= 1 or raise "too many defined primary keys! #{defined_primary_keys.inspect}"
          existing_primary_key = existing_primary_keys.first
          defined_primary_key = defined_primary_keys.first

          existing_primary_key_columns = (existing_primary_key&.columns || []).map { |col_name| to_rename[col_name] || col_name }

          if !ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
            change_primary_key =
              if (existing_primary_key || defined_primary_key) &&
                 existing_primary_key_columns != defined_primary_key&.columns
                ::DeclareSchema::SchemaChange::PrimaryKeyChange.new(new_table_name, existing_primary_key_columns, defined_primary_key&.columns)
              end
          end

          indexes_to_drop = existing_indexes_without_primary_key - model_indexes_without_primary_key
          indexes_to_add = model_indexes_without_primary_key - existing_indexes_without_primary_key

          renamed_indexes_to_drop, renamed_indexes_to_add = index_changes_due_to_column_renames(indexes_to_drop, indexes_to_add, to_rename)

          drop_indexes = (indexes_to_drop - renamed_indexes_to_drop).map do |i|
            ::DeclareSchema::SchemaChange::IndexRemove.new(new_table_name, i.columns, unique: i.unique, where: i.where, name: i.name)
          end

          add_indexes = (indexes_to_add - renamed_indexes_to_add).map do |i|
            ::DeclareSchema::SchemaChange::IndexAdd.new(new_table_name, i.columns, unique: i.unique, where: i.where, name: i.name)
          end

          # the order is important here - adding a :unique, for instance needs to remove then add
          [Array(change_primary_key) + drop_indexes + add_indexes]
        end

        def index_changes_due_to_column_renames(indexes_to_drop, indexes_to_add, to_rename)
          indexes_to_drop.each_with_object([[], []]) do |index_to_drop, (renamed_indexes_to_drop, renamed_indexes_to_add)|
            renamed_columns = index_to_drop.columns.map do |column|
              to_rename.fetch(column, column)
            end.sort

            if (index_to_add = indexes_to_add.find { |index_to_add| renamed_columns == index_to_add.columns.sort })
              renamed_indexes_to_drop << index_to_drop
              renamed_indexes_to_add << index_to_add
            end
          end
        end

        def change_foreign_key_constraints(model, old_table_name, to_rename)
          ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/) and raise ArgumentError, 'SQLite does not support foreign keys'
          ::DeclareSchema.default_generate_foreign_keys or return []

          existing_fks = ::DeclareSchema::Model::ForeignKeyDefinition.for_model(model, old_table_name: old_table_name)
          model_fks = model.constraint_specs

          fks_to_drop = existing_fks - model_fks
          fks_to_add = model_fks - existing_fks

          renamed_fks_to_drop, renamed_fks_to_add = foreign_key_changes_due_to_column_renames(fks_to_drop, fks_to_add, to_rename)

          drop_fks = (fks_to_drop - renamed_fks_to_drop).map do |fk|
            ::DeclareSchema::SchemaChange::ForeignKeyRemove.new(fk.child_table_name, fk.parent_table_name,
                                                                column_name: fk.foreign_key_name, name: fk.constraint_name)
          end

          add_fks = (fks_to_add - renamed_fks_to_add).map do |fk|
            # next if fk.parent.constantize.abstract_class || fk.parent == fk.model.class_name
            ::DeclareSchema::SchemaChange::ForeignKeyAdd.new(fk.child_table_name, fk.parent_table_name,
                                                             column_name: fk.foreign_key_name, name: fk.constraint_name)
          end

          [drop_fks + add_fks]
        end

        def foreign_key_changes_due_to_column_renames(fks_to_drop, fks_to_add, to_rename)
          fks_to_drop.each_with_object([[], []]) do |fk_to_drop, (renamed_fks_to_drop, renamed_fks_to_add)|
            fk_to_add = fks_to_add.find do |fk_to_add|
              fk_to_add.child_table_name == fk_to_drop.child_table_name &&
                fk_to_add.parent_table_name == fk_to_drop.parent_table_name &&
                fk_to_add.foreign_key == to_rename[fk_to_drop.foreign_key]
            end

            if fk_to_add
              renamed_fks_to_drop << fk_to_drop
              renamed_fks_to_add << fk_to_add
            end
          end
        end

        def fk_field_options(model, field_name)
          foreign_key = model.constraint_specs.find { |fk| field_name == fk.foreign_key.to_s }
          if foreign_key && (parent_table = foreign_key.parent_table_name)
            parent_columns = connection.columns(parent_table) rescue []
            pk_limit =
              if (pk_column = parent_columns.find { |column| column.name.to_s == "id" }) # right now foreign keys assume id is the target
                pk_column.limit
              else
                8
              end

            { limit: pk_limit }
          else
            {}
          end
        end

        def change_table_options(model, current_table_name)
          old_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.for_model(model, current_table_name)
          new_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.new(model.table_name, **table_options_for_model(model))

          if old_options_definition.equivalent?(new_options_definition)
            []
          else
            [
              ::DeclareSchema::SchemaChange::TableChange.new(current_table_name,
                                                             old_options_definition.table_options,
                                                             new_options_definition.table_options)
            ]
          end
        end

        def with_previous_model_table_name(model, table_name)
          model_table_name, model.table_name = model.table_name, table_name
          yield
        ensure
          model.table_name = model_table_name
        end

        def add_column_back(model, current_table_name, col_name)
          with_previous_model_table_name(model, current_table_name) do
            column = model.columns_hash[col_name] or raise "no columns_hash entry found for #{col_name} in #{model.inspect}"
            col_spec = ::DeclareSchema::Model::Column.new(model, current_table_name, column)
            schema_attributes = col_spec.schema_attributes
            type = schema_attributes.delete(:type) or raise "no :type found in #{schema_attributes.inspect}"
            [type, schema_attributes]
          end
        end

        def change_column_back(model, current_table_name, col_name)
          with_previous_model_table_name(model, current_table_name) do
            column = model.columns_hash[col_name] or raise "no columns_hash entry found for #{col_name} in #{model.inspect}"
            col_spec = ::DeclareSchema::Model::Column.new(model, current_table_name, column)
            schema_attributes = col_spec.schema_attributes
            type = schema_attributes.delete(:type) or raise "no :type found in #{schema_attributes.inspect}"
            [type, schema_attributes]
          end
        end

        def default_collation_from_charset(charset)
          case charset
          when "utf8"
            "utf8_general_ci"
          when "utf8mb4"
            "utf8mb4_general_ci"
          end
        end

        SchemaDumper = ActiveRecord::ConnectionAdapters::SchemaDumper


        def add_table_back(table)
          dumped_schema_stream = StringIO.new
          SchemaDumper.send(:new, ActiveRecord::Base.connection).send(:table, table, dumped_schema_stream)

          dumped_schema = dumped_schema_stream.string.strip.gsub!("\n  ", "\n")
          if connection.class.name.match?(/mysql/i)
            fix_mysql_charset_and_collation(dumped_schema)
          else
            dumped_schema
          end
        end

        # TODO: rewrite this method to use charset and collation variables rather than manipulating strings. -Colin
        def fix_mysql_charset_and_collation(dumped_schema)
          if !dumped_schema['options: ']
            dumped_schema.sub!('",', "\", options: \"DEFAULT CHARSET=#{::DeclareSchema.default_charset} "+
              "COLLATE=#{::DeclareSchema.default_collation}\",")
          end
          default_charset   = dumped_schema[/CHARSET=(\w+)/, 1]   or raise "unable to find charset in #{dumped_schema.inspect}"
          default_collation = dumped_schema[/COLLATE=(\w+)/, 1] || default_collation_from_charset(default_charset) or
            raise "unable to find collation in #{dumped_schema.inspect} or charset #{default_charset.inspect}"
          dumped_schema.split("\n").map do |line|
            if line['t.text'] || line['t.string']
              if !line['charset: ']
                if line['collation: ']
                  line.sub!('collation: ', "charset: #{default_charset.inspect}, collation: ")
                else
                  line << ", charset: #{default_charset.inspect}"
                end
              end
              line['collation: '] or line << ", collation: #{default_collation.inspect}"
            end
            line
          end.join("\n")
        end
      end
    end
  end
end
