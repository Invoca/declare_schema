# frozen_string_literal: true

require 'rails/generators/migration'
require 'rails/generators/active_record'
require 'generators/declare_schema/support/thor_shell'
require 'declare_schema/model/field_spec'

module DeclareSchema
  class MigrationGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    argument :name, type: :string, optional: true

    include Rails::Generators::Migration
    include DeclareSchema::Support::ThorShell

    class << self
      # the Rails::Generators::Migration.next_migration_number gives a NotImplementedError
      # in Rails 3.0.0.beta4, so we need to implement the logic of ActiveRecord.
      # For other ORMs we will wait for the rails implementation
      # see http://groups.google.com/group/rubyonrails-talk/browse_thread/thread/a507ce419076cda2
      def next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def banner
        "rails generate declare_schema:migration #{arguments.map(&:usage).join(' ')} [options]"
      end
    end

    class_option :drop,
                 aliases: '-d',
                 type: :boolean,
                 desc: "Don't prompt with 'drop or rename' - just drop everything"

    class_option :default_name,
                 aliases: '-n',
                 type: :boolean,
                 desc: "Don't prompt for a migration name - just pick one"

    class_option :migrate,
                 aliases: '-m',
                 type: :boolean,
                 desc: "After generating migration, run it"

    def migrate
      return if migrations_pending?

      generator = Generators::DeclareSchema::Migration::Migrator.new do |to_create, to_drop, kind_str, name_prefix|
        extract_renames!(to_create, to_drop, kind_str, name_prefix)
      end

      up, down = generator.generate

      if up.blank?
        say "Database and models match -- nothing to change"
        return
      end

      say "\n---------- Up Migration ----------"
      say up
      say "----------------------------------"

      say "\n---------- Down Migration --------"
      say down
      say "----------------------------------"

      final_migration_name =
        name.presence ||
        if !options[:default_name]
          choose("\nMigration filename (spaces will be converted to _) [#{default_migration_name}]:", /^[a-z0-9_ ]*$/,
                 default_migration_name).strip.gsub(' ', '_').presence
        end ||
        default_migration_name

      @up = indent(up.strip, 4)
      @down = indent(down.strip, 4)
      @migration_class_name = final_migration_name.camelize

      migration_template('migration.rb.erb', "db/migrate/#{final_migration_name.underscore}.rb")

      db_migrate_command = ::DeclareSchema.db_migrate_command
      if options[:migrate]
        say db_migrate_command
        bare_rails_command = db_migrate_command.sub(/\Abundle exec +/, '').sub(/\Arake +|rails +/, '')
        rails_command(bare_rails_command)
      else
        say "\nNot running migration since --migrate not given. When you are ready, run:\n\n   #{db_migrate_command}\n\n"
      end
    rescue ::DeclareSchema::UnknownTypeError => ex
      say "Invalid field type: #{ex}"
    end

    private

    def migrations_pending?
      pending_migrations = load_pending_migrations

      pending_migrations.any?.tap do |any|
        if any
          say "You have #{pending_migrations.size} pending migration#{'s' if pending_migrations.size > 1}:"
          pending_migrations.each do |pending_migration|
            say format('  %4d %s', pending_migration.version, pending_migration.name)
          end
        end
      end
    end

    def load_migrations
      if ActiveSupport.version >= Gem::Version.new('7.1.0')
        ActiveRecord::MigrationContext.new(
          ActiveRecord::Migrator.migrations_paths,
          ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection),
          ActiveRecord::InternalMetadata.new(ActiveRecord::Base.connection)
        ).migrations
      else
        ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths, ActiveRecord::SchemaMigration).migrations
      end
    end

    def load_pending_migrations
      migrations = load_migrations
      if ActiveSupport.version >= Gem::Version.new('7.1.0')
        ActiveRecord::Migrator.new(
          :up,
          migrations,
          ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection),
          ActiveRecord::InternalMetadata.new(ActiveRecord::Base.connection)
        ).pending_migrations
      else
        ActiveRecord::Migrator.new(:up, migrations, ActiveRecord::SchemaMigration).pending_migrations
      end
    end

    def extract_renames!(to_create, to_drop, kind_str, name_prefix = "")
      to_rename = {}

      unless options[:drop]

        rename_to_choices = to_create
        to_drop.dup.each do |t|
          loop do
            if rename_to_choices.empty?
              say "\nCONFIRM DROP! #{kind_str} #{name_prefix}#{t}"
              resp = ask("Enter 'drop #{t}' to confirm or press enter to keep:").strip
              if resp == "drop #{t}"
                break
              elsif resp.empty?
                to_drop.delete(t)
                break
              else
                next
              end
            else
              say "\nDROP, RENAME or KEEP?: #{kind_str} #{name_prefix}#{t}"
              say "Rename choices: #{to_create * ', '}"
              resp = ask("Enter either 'drop #{t}' or one of the rename choices or press enter to keep:").strip

              if resp == "drop #{t}"
                # Leave things as they are
                break
              else
                resp.gsub!(' ', '_')
                to_drop.delete(t)
                if resp.in?(rename_to_choices)
                  to_rename[t] = resp
                  to_create.delete(resp)
                  rename_to_choices.delete(resp)
                  break
                elsif resp.empty?
                  break
                else
                  next
                end
              end
            end
          end
        end
      end
      to_rename
    end

    def default_migration_name
      Generators::DeclareSchema::Migration::Migrator.default_migration_name
    end
  end
end

module Generators
  module DeclareSchema
    module Migration
      MigrationGenerator = ::DeclareSchema::MigrationGenerator
    end
  end
end
