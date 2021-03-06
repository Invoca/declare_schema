# frozen_string_literal: true

require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'

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

          def run(renames = {})
            g = Migrator.new
            g.renames = renames
            g.generate
          end

          def default_migration_name
            existing = Dir["#{Rails.root}/db/migrate/*declare_schema_migration*"]
            max = existing.grep(/([0-9]+)\.rb$/) { Regexp.last_match(1).to_i }.max.to_i
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

        def initialize(ambiguity_resolver = {})
          @ambiguity_resolver = ambiguity_resolver
          @drops = []
          @renames = nil
        end

        attr_accessor :renames

        def load_rails_models
          ActiveRecord::Migration.verbose = false

          Rails.application.eager_load!
          Rails::Engine.subclasses.each(&:eager_load!)
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
          if renames
            # A hash of table renames has been provided

            to_rename = {}
            renames.each_pair do |old_name, new_name|
              new_name = new_name[:table_name] if new_name.is_a?(Hash)
              next unless new_name

              if to_create.delete(new_name.to_s) && to_drop.delete(old_name.to_s)
                to_rename[old_name.to_s] = new_name.to_s
              else
                raise Error, "Invalid table rename specified: #{old_name} => #{new_name}"
              end
            end
            to_rename

          elsif @ambiguity_resolver
            @ambiguity_resolver.call(to_create, to_drop, "table", nil)

          else
            raise Error, "Unable to resolve migration ambiguities"
          end
        end

        def extract_column_renames!(to_add, to_remove, table_name)
          if renames
            to_rename = {}
            if (column_renames = renames&.[](table_name.to_sym))
              # A hash of table renames has been provided

              column_renames.each_pair do |old_name, new_name|
                if to_add.delete(new_name.to_s) && to_remove.delete(old_name.to_s)
                  to_rename[old_name.to_s] = new_name.to_s
                else
                  raise Error, "Invalid rename specified: #{old_name} => #{new_name}"
                end
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
          to_change = model_table_names
          to_rename = extract_table_renames!(to_create, to_drop)

          renames = to_rename.map do |old_name, new_name|
            "rename_table :#{old_name}, :#{new_name}"
          end * "\n"
          undo_renames = to_rename.map do |old_name, new_name|
            "rename_table :#{new_name}, :#{old_name}"
          end * "\n"

          drops = to_drop.map do |t|
            "drop_table :#{t}"
          end * "\n"
          undo_drops = to_drop.map do |t|
            add_table_back(t)
          end * "\n\n"

          creates = to_create.map do |t|
            create_table(models_by_table_name[t])
          end * "\n\n"
          undo_creates = to_create.map do |t|
            "drop_table :#{t}"
          end * "\n"

          changes                    = []
          undo_changes               = []
          index_changes              = []
          undo_index_changes         = []
          fk_changes                 = []
          undo_fk_changes            = []
          table_options_changes      = []
          undo_table_options_changes = []

          to_change.each do |t|
            model = models_by_table_name[t]
            table = to_rename.key(t) || model.table_name
            if table.in?(db_tables)
              change, undo, index_change, undo_index, fk_change, undo_fk, table_options_change, undo_table_options_change = change_table(model, table)
              changes << change
              undo_changes << undo
              index_changes << index_change
              undo_index_changes << undo_index
              fk_changes << fk_change
              undo_fk_changes << undo_fk
              table_options_changes << table_options_change
              undo_table_options_changes << undo_table_options_change
            end
          end

          up = [renames, drops, creates, changes, index_changes, fk_changes, table_options_changes].flatten.reject(&:blank?) * "\n\n"
          down = [undo_changes, undo_renames, undo_drops, undo_creates, undo_index_changes, undo_fk_changes, undo_table_options_changes].flatten.reject(&:blank?) * "\n\n"

          [up, down]
        end

        def create_table(model)
          longest_field_name       = model.field_specs.values.map { |f| f.type.to_s.length }.max
          disable_auto_increment   = model.respond_to?(:disable_auto_increment) && model.disable_auto_increment
          table_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.new(model.table_name, table_options_for_model(model))
          field_definitions        = [
            ("t.integer :id, limit: 8, auto_increment: false, primary_key: true" if disable_auto_increment),
            *(model.field_specs.values.sort_by(&:position).map { |f| create_field(f, longest_field_name) })
          ].compact

          <<~EOS.strip
            create_table #{model.table_name.to_sym.inspect}, #{create_table_options(model, disable_auto_increment)} do |t|
              #{field_definitions.join("\n")}
            end

            #{table_options_definition.alter_table_statement unless ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)}
            #{create_indexes(model).join("\n")               if ::DeclareSchema.default_generate_indexing}
            #{create_constraints(model).join("\n")           if ::DeclareSchema.default_generate_foreign_keys}
          EOS
        end

        def create_table_options(model, disable_auto_increment)
          primary_key = model._defined_primary_key
          if primary_key.blank? || disable_auto_increment
            "id: false"
          elsif primary_key == "id"
            "id: :bigint"
          else
            "primary_key: :#{primary_key}"
          end
        end

        def table_options_for_model(model)
          if ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
            {}
          else
            {
              charset:   model.table_options[:charset] || ::DeclareSchema.default_charset,
              collation: model.table_options[:collation] || ::DeclareSchema.default_collation
            }
          end
        end

        def create_indexes(model)
          model.index_definitions.map { |i| i.to_add_statement(model.table_name) }
        end

        def create_constraints(model)
          model.constraint_specs.map { |fk| fk.to_add_statement }
        end

        def create_field(field_spec, field_name_width)
          options = field_spec.sql_options.merge(fk_field_options(field_spec.model, field_spec.name))
          args = [field_spec.name.inspect] + format_options(options.compact)
          format("t.%-*s %s", field_name_width, field_spec.type, args.join(', '))
        end

        def change_table(model, current_table_name)
          new_table_name = model.table_name

          db_columns = model.connection.columns(current_table_name).index_by(&:name)
          key_missing = db_columns[model._defined_primary_key].nil? && model._defined_primary_key.present?
          if model._defined_primary_key.present?
            db_columns.delete(model._defined_primary_key)
          end

          model_column_names = model.field_specs.keys.map(&:to_s)
          db_column_names = db_columns.keys.map(&:to_s)

          to_add = model_column_names - db_column_names
          to_add += [model._defined_primary_key] if key_missing && model._defined_primary_key.present?
          to_remove = db_column_names - model_column_names
          to_remove -= [model._defined_primary_key.to_sym] if model._defined_primary_key.present?

          to_rename = extract_column_renames!(to_add, to_remove, new_table_name)

          db_column_names -= to_rename.keys
          db_column_names |= to_rename.values
          to_change = db_column_names & model_column_names

          renames = to_rename.map do |old_name, new_name|
            "rename_column :#{new_table_name}, :#{old_name}, :#{new_name}"
          end
          undo_renames = to_rename.map do |old_name, new_name|
            "rename_column :#{new_table_name}, :#{new_name}, :#{old_name}"
          end

          to_add = to_add.sort_by { |c| model.field_specs[c]&.position || 0 }
          adds = to_add.map do |c|
            args =
              if (spec = model.field_specs[c])
                options = spec.sql_options.merge(fk_field_options(model, c))
                ["#{spec.type.to_sym.inspect}", *format_options(options.compact)]
              else
                [":integer"]
              end
            ["add_column :#{new_table_name}, :#{c}", *args].join(', ')
          end
          undo_adds = to_add.map do |c|
            "remove_column :#{new_table_name}, :#{c}"
          end

          removes = to_remove.map do |c|
            "remove_column :#{new_table_name}, :#{c}"
          end
          undo_removes = to_remove.map do |c|
            add_column_back(model, current_table_name, c)
          end

          old_names = to_rename.invert
          changes = []
          undo_changes = []
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
              changes << ["change_column #{new_table_name.to_sym.inspect}", col_name_to_change.to_sym.inspect,
                          type.to_sym.inspect, *format_options(normalized_schema_attrs)].join(", ")
              undo_changes << change_column_back(model, current_table_name, orig_col_name)
            end
          end

          index_changes, undo_index_changes = change_indexes(model, current_table_name, to_remove)
          fk_changes, undo_fk_changes = if ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
                                          [[], []]
                                        else
                                          change_foreign_key_constraints(model, current_table_name)
                                        end
          table_options_changes, undo_table_options_changes = if ActiveRecord::Base.connection.class.name.match?(/mysql/i)
                                                                change_table_options(model, current_table_name)
                                                              else
                                                                [[], []]
                                                              end

          [(renames + adds + removes + changes)                     * "\n",
           (undo_renames + undo_adds + undo_removes + undo_changes) * "\n",
           index_changes                                            * "\n",
           undo_index_changes                                       * "\n",
           fk_changes                                               * "\n",
           undo_fk_changes                                          * "\n",
           table_options_changes                                    * "\n",
           undo_table_options_changes                               * "\n"]
        end

        def change_indexes(model, old_table_name, to_remove)
          ::DeclareSchema.default_generate_indexing or return [[], []]

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
          existing_has_primary_key = existing_indexes.any? do |i|
            i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME &&
              !i.fields.all? { |f| to_remove.include?(f) } # if we're removing the primary key column(s), the primary key index will be removed too
          end
          model_has_primary_key    = model_indexes.any?    { |i| i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME }

          undo_add_indexes = []
          add_indexes = (model_indexes - existing_indexes).map do |i|
            undo_add_indexes << drop_index(old_table_name, i.name) unless i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME
            i.to_add_statement(new_table_name, existing_has_primary_key)
          end
          undo_drop_indexes = []
          drop_indexes = (existing_indexes - model_indexes).map do |i|
            undo_drop_indexes << i.to_add_statement(old_table_name, model_has_primary_key)
            drop_index(new_table_name, i.name) unless i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME
          end.compact

          # the order is important here - adding a :unique, for instance needs to remove then add
          [drop_indexes + add_indexes, undo_add_indexes + undo_drop_indexes]
        end

        def drop_index(table, name)
          # see https://hobo.lighthouseapp.com/projects/8324/tickets/566
          # for why the rescue exists
          "remove_index :#{table}, name: :#{name} rescue ActiveRecord::StatementInvalid"
        end

        def change_foreign_key_constraints(model, old_table_name)
          ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/) and raise ArgumentError, 'SQLite does not support foreign keys'
          ::DeclareSchema.default_generate_foreign_keys or return [[], []]

          new_table_name = model.table_name
          existing_fks = ::DeclareSchema::Model::ForeignKeyDefinition.for_model(model, old_table_name)
          model_fks = model.constraint_specs

          undo_add_fks = []
          add_fks = (model_fks - existing_fks).map do |fk|
            # next if fk.parent.constantize.abstract_class || fk.parent == fk.model.class_name
            undo_add_fks << remove_foreign_key(old_table_name, fk.constraint_name)
            fk.to_add_statement
          end

          undo_drop_fks = []
          drop_fks = (existing_fks - model_fks).map do |fk|
            undo_drop_fks << fk.to_add_statement
            remove_foreign_key(new_table_name, fk.constraint_name)
          end

          [drop_fks + add_fks, undo_add_fks + undo_drop_fks]
        end

        def remove_foreign_key(old_table_name, fk_name)
          "remove_foreign_key(#{old_table_name.inspect}, name: #{fk_name.to_s.inspect})"
        end

        def format_options(options)
          options.map do |k, v|
            if k.is_a?(Symbol)
              "#{k}: #{v.inspect}"
            else
              "#{k.inspect} => #{v.inspect}"
            end
          end
        end

        def fk_field_options(model, field_name)
          foreign_key = model.constraint_specs.find { |fk| field_name == fk.foreign_key.to_s }
          if foreign_key && (parent_table = foreign_key.parent_table_name)
            parent_columns = connection.columns(parent_table) rescue []
            pk_limit =
              if (pk_column = parent_columns.find { |column| column.name.to_s == "id" }) # right now foreign keys assume id is the target
                if Rails::VERSION::MAJOR < 5
                  pk_column.cast_type.limit
                else
                  pk_column.limit
                end
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
          new_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.new(model.table_name, table_options_for_model(model))

          if old_options_definition.equivalent?(new_options_definition)
            [[], []]
          else
            [
              [new_options_definition.alter_table_statement],
              [old_options_definition.alter_table_statement]
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
            ["add_column :#{current_table_name}, :#{col_name}, #{type.inspect}", *format_options(schema_attributes)].join(', ')
          end
        end

        def change_column_back(model, current_table_name, col_name)
          with_previous_model_table_name(model, current_table_name) do
            column = model.columns_hash[col_name] or raise "no columns_hash entry found for #{col_name} in #{model.inspect}"
            col_spec = ::DeclareSchema::Model::Column.new(model, current_table_name, column)
            schema_attributes = col_spec.schema_attributes
            type = schema_attributes.delete(:type) or raise "no :type found in #{schema_attributes.inspect}"
            ["change_column #{current_table_name.to_sym.inspect}", col_name.to_sym.inspect, type.to_sym.inspect, *format_options(schema_attributes)].join(', ')
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

        SchemaDumper = case Rails::VERSION::MAJOR
                       when 4
                         ActiveRecord::SchemaDumper
                       else
                         ActiveRecord::ConnectionAdapters::SchemaDumper
                       end

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
