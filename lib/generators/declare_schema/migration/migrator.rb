# frozen_string_literal: true

require 'active_record'

module Generators
  module DeclareSchema
    module Migration
      HabtmModelShim = Struct.new(:join_table, :foreign_keys, :foreign_key_classes, :connection) do
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

        def table_options
          {}
        end

        def table_name
          join_table
        end

        def table_exists?
          ActiveRecord::Migration.table_exists? table_name
        end

        def field_specs
          i = 0
          foreign_keys.each_with_object({}) do |v, result|
            result[v] = ::DeclareSchema::Model::FieldSpec.new(self, v, :integer, position: i, null: false)
            i += 1
          end
        end

        def primary_key
          false # no single-column primary key
        end

        def index_definitions_with_primary_key
          [
            ::DeclareSchema::Model::IndexDefinition.new(self, foreign_keys, unique: true, name: ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME),
            ::DeclareSchema::Model::IndexDefinition.new(self, foreign_keys.last) # not unique by itself; combines with primary key to be unique
          ]
        end

        alias_method :index_definitions, :index_definitions_with_primary_key

        def ignore_indexes
          []
        end

        def constraint_specs
          [
            ::DeclareSchema::Model::ForeignKeyDefinition.new(self, foreign_keys.first, parent_table: foreign_key_classes.first.table_name, constraint_name: "#{join_table}_FK1", dependent: :delete),
            ::DeclareSchema::Model::ForeignKeyDefinition.new(self, foreign_keys.last, parent_table: foreign_key_classes.last.table_name, constraint_name: "#{join_table}_FK2", dependent: :delete)
          ]
        end
      end

      class Migrator
        class Error < RuntimeError; end

        DEFAULT_CHARSET   = "utf8mb4"
        DEFAULT_COLLATION = "utf8mb4_bin"

        @ignore_models                        = []
        @ignore_tables                        = []
        @before_generating_migration_callback = nil
        @active_record_class                  = ActiveRecord::Base
        @default_charset                      = DEFAULT_CHARSET
        @default_collation                    = DEFAULT_COLLATION

        class << self
          attr_accessor :ignore_models, :ignore_tables, :disable_indexing, :disable_constraints
          attr_reader :active_record_class, :default_charset, :default_collation, :before_generating_migration_callback

          def default_charset=(charset)
            charset.is_a?(String) or raise ArgumentError, "charset must be a string (got #{charset.inspect})"
            @default_charset = charset
          end

          def default_collation=(charset)
            charset.is_a?(String) or raise ArgumentError, "charset must be a string (got #{charset.inspect})"
            @default_collation = charset
          end

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

          def fix_native_types(types)
            case connection.class.name
            when /mysql/i
              types[:integer][:limit] ||= 11
              types[:text][:limit]    ||= 0xffff
              types[:binary][:limit]  ||= 0xffff
            end
            types
          end

          def native_types
            @native_types ||= fix_native_types(connection.native_database_types)
          end

          def before_generating_migration(&block)
            block or raise ArgumentError, 'A block is required when setting the before_generating_migration callback'
            @before_generating_migration_callback = block
          end
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
            models_by_table_name[name] = HabtmModelShim.from_reflection(refls.first)
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
            revert_table(t)
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
          longest_field_name       = model.field_specs.values.map { |f| f.sql_type.to_s.length }.max
          disable_auto_increment   = model.respond_to?(:disable_auto_increment) && model.disable_auto_increment
          table_options_definition = ::DeclareSchema::Model::TableOptionsDefinition.new(model.table_name, table_options_for_model(model))
          field_definitions        = [
            disable_auto_increment ? "t.integer :id, limit: 8, auto_increment: false, primary_key: true" : nil,
            *(model.field_specs.values.sort_by(&:position).map { |f| create_field(f, longest_field_name) })
          ].compact

          <<~EOS.strip
            create_table :#{model.table_name}, #{create_table_options(model, disable_auto_increment)} do |t|
              #{field_definitions.join("\n")}
            end

            #{table_options_definition.alter_table_statement unless ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)}
            #{create_indexes(model).join("\n")               unless Migrator.disable_indexing}
            #{create_constraints(model).join("\n")           unless Migrator.disable_indexing}
          EOS
        end

        def create_table_options(model, disable_auto_increment)
          if model.primary_key.blank? || disable_auto_increment
            "id: false"
          elsif model.primary_key == "id"
            "id: :bigint"
          else
            "primary_key: :#{model.primary_key}"
          end
        end

        def table_options_for_model(model)
          if ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/)
            {}
          else
            {
              charset:   model.table_options[:charset] || Migrator.default_charset,
              collation: model.table_options[:collation] || Migrator.default_collation
            }
          end
        end

        def create_indexes(model)
          model.index_definitions.map { |i| i.to_add_statement(model.table_name) }
        end

        def create_constraints(model)
          model.constraint_specs.map { |fk| fk.to_add_statement(model.table_name) }
        end

        def create_field(field_spec, field_name_width)
          options = fk_field_options(field_spec.model, field_spec.name).merge(field_spec.sql_options)
          args = [field_spec.name.inspect] + format_options(options, field_spec.sql_type)
          format("t.%-*s %s", field_name_width, field_spec.sql_type, args.join(', '))
        end

        def change_table(model, current_table_name)
          new_table_name = model.table_name

          db_columns = model.connection.columns(current_table_name).index_by(&:name)
          key_missing = db_columns[model.primary_key].nil? && model.primary_key.present?
          if model.primary_key.present?
            db_columns.delete(model.primary_key)
          end

          model_column_names = model.field_specs.keys.map(&:to_s)
          db_column_names = db_columns.keys.map(&:to_s)

          to_add = model_column_names - db_column_names
          to_add += [model.primary_key] if key_missing && model.primary_key.present?
          to_remove = db_column_names - model_column_names
          to_remove -= [model.primary_key.to_sym] if model.primary_key.present?

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
                options = fk_field_options(model, c).merge(spec.sql_options)
                [":#{spec.sql_type}", *format_options(options, spec.sql_type)]
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
            revert_column(current_table_name, c)
          end

          old_names = to_rename.invert
          changes = []
          undo_changes = []
          to_change.each do |c|
            col_name = old_names[c] || c
            col = db_columns[col_name]
            spec = model.field_specs[c]
            if spec.different_to?(current_table_name, col) # TODO: TECH-4814 DRY this up to a diff function that returns the differences. It's different if it has differences. -Colin
              change_spec = fk_field_options(model, c)
              change_spec[:limit]     ||= spec.limit   if (spec.sql_type != :text ||
                                                         ::DeclareSchema::Model::FieldSpec.mysql_text_limits?) &&
                                                          (spec.limit || col.limit)
              change_spec[:precision]     = spec.precision     unless spec.precision.nil?
              change_spec[:scale]         = spec.scale         unless spec.scale.nil?
              change_spec[:null]          = spec.null          unless spec.null && col.null
              change_spec[:default]       = spec.default       unless spec.default.nil? && col.default.nil?
              change_spec[:charset]       = spec.charset       unless spec.charset.nil?
              change_spec[:collation]     = spec.collation     unless spec.collation.nil?

              changes << "change_column :#{new_table_name}, :#{c}, " +
                         ([":#{spec.sql_type}"] + format_options(change_spec, spec.sql_type, changing: true)).join(", ")
              back = change_column_back(current_table_name, col_name)
              undo_changes << back unless back.blank?
            end
          end.compact

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

          [(renames + adds + removes + changes) * "\n",
           (undo_renames + undo_adds + undo_removes + undo_changes) * "\n",
           index_changes * "\n",
           undo_index_changes * "\n",
           fk_changes * "\n",
           undo_fk_changes * "\n",
           table_options_changes * "\n",
           undo_table_options_changes * "\n"]
        end

        def change_indexes(model, old_table_name, to_remove)
          return [[], []] if Migrator.disable_constraints

          new_table_name = model.table_name
          existing_indexes = ::DeclareSchema::Model::IndexDefinition.for_model(model, old_table_name)
          model_indexes_with_equivalents = model.index_definitions_with_primary_key
          model_indexes = model_indexes_with_equivalents.map do |i|
            if i.explicit_name.nil?
              if ex = existing_indexes.find { |e| i != e && e.equivalent?(i) }
                i.with_name(ex.name)
              end
            end || i
          end
          existing_has_primary_key = existing_indexes.any? do |i|
            i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME &&
              !i.fields.all? { |f| to_remove.include?(f) } # if we're removing the primary key column(s), the primary key index will be removed too
          end
          model_has_primary_key    = model_indexes.any?    { |i| i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME }

          add_indexes_init = model_indexes - existing_indexes
          drop_indexes_init = existing_indexes - model_indexes
          undo_add_indexes = []
          undo_drop_indexes = []
          add_indexes = add_indexes_init.map do |i|
            undo_add_indexes << drop_index(old_table_name, i.name) unless i.name == ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME
            i.to_add_statement(new_table_name, existing_has_primary_key)
          end
          drop_indexes = drop_indexes_init.map do |i|
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
          ActiveRecord::Base.connection.class.name.match?(/SQLite3Adapter/) and raise 'SQLite does not support foreign keys'
          return [[], []] if Migrator.disable_indexing

          new_table_name = model.table_name
          existing_fks = ::DeclareSchema::Model::ForeignKeyDefinition.for_model(model, old_table_name)
          model_fks = model.constraint_specs
          add_fks = model_fks - existing_fks
          drop_fks = existing_fks - model_fks
          undo_add_fks = []
          undo_drop_fks = []

          add_fks.map! do |fk|
            # next if fk.parent.constantize.abstract_class || fk.parent == fk.model.class_name
            undo_add_fks << remove_foreign_key(old_table_name, fk.options[:constraint_name])
            fk.to_add_statement
          end.compact

          drop_fks.map! do |fk|
            undo_drop_fks << fk.to_add_statement
            remove_foreign_key(new_table_name, fk.options[:constraint_name])
          end

          [drop_fks + add_fks, undo_add_fks + undo_drop_fks]
        end

        def remove_foreign_key(old_table_name, fk_name)
          "remove_foreign_key('#{old_table_name}', name: '#{fk_name}')"
        end

        def format_options(options, type, changing: false)
          options.map do |k, v|
            unless changing
              if (k == :limit && type == :decimal) || (k == :null && v == true)
                next
              end
            end

            next if k == :limit && type == :text && !::DeclareSchema::Model::FieldSpec.mysql_text_limits?

            if k.is_a?(Symbol)
              "#{k}: #{v.inspect}"
            else
              "#{k.inspect} => #{v.inspect}"
            end
          end.compact
        end

        def fk_field_options(model, field_name)
          foreign_key = model.constraint_specs.find { |fk| field_name == fk.foreign_key.to_s }
          if foreign_key && (parent_table = foreign_key.parent_table_name)
            parent_columns = connection.columns(parent_table) rescue []
            pk_limit  =
              if (pk_column = parent_columns.find { |column| column.name.to_s == "id" }) # right now foreign keys assume id is the target
                if Rails::VERSION::MAJOR <= 4
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

        # TODO: TECH-4814 remove all methods from here through end of file
        def revert_table(table)
          res = StringIO.new
          schema_dumper_klass = case Rails::VERSION::MAJOR
                                when 4
                                  ActiveRecord::SchemaDumper
                                else
                                  ActiveRecord::ConnectionAdapters::SchemaDumper
                                end
          schema_dumper_klass.send(:new, ActiveRecord::Base.connection).send(:table, table, res)

          result = res.string.strip.gsub("\n  ", "\n")
          if connection.class.name.match?(/mysql/i)
            if !result['options: ']
              result = result.sub('",', "\", options: \"DEFAULT CHARSET=#{Generators::DeclareSchema::Migration::Migrator.default_charset} "+
                                   "COLLATE=#{Generators::DeclareSchema::Migration::Migrator.default_collation}\",")
            end
            default_charset   = result[/CHARSET=(\w+)/, 1]   or raise "unable to find charset in #{result.inspect}"
            default_collation = result[/COLLATE=(\w+)/, 1] or raise "unable to find collation in #{result.inspect}"
            result = result.split("\n").map do |line|
              if line['t.text'] || line['t.string']
                if !line['charset: ']
                  if line['collation: ']
                    line = line.sub('collation: ', "charset: #{default_charset.inspect}, collation: ")
                  else
                    line += ", charset: #{default_charset.inspect}"
                  end
                end
                line['collation: '] or line += ", collation: #{default_collation.inspect}"
              end
              line
            end.join("\n")
          end
          result
        end

        def column_options_from_reverted_table(table, column)
          revert = revert_table(table)
          if (md = revert.match(/\s*t\.column\s+"#{column}",\s+(:[a-zA-Z0-9_]+)(?:,\s+(.*?)$)?/m))
            # Ugly migration
            _, type, options = *md
          elsif (md = revert.match(/\s*t\.([a-z_]+)\s+"#{column}"(?:,\s+(.*?)$)?/m))
            # Sexy migration
            _, string_type, options = *md
            type = ":#{string_type}"
          end
          type or raise "unable to find column options for #{table}.#{column} in #{revert.inspect}"
          [type, options]
        end

        def change_column_back(table, column)
          type, options = column_options_from_reverted_table(table, column)
          ["change_column :#{table}, :#{column}, #{type}", options&.strip].compact.join(', ')
        end

        def revert_column(table, column)
          type, options = column_options_from_reverted_table(table, column)
          ["add_column :#{table}, :#{column}, #{type}", options&.strip].compact.join(', ')
        end
      end
    end
  end
end
