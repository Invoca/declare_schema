# frozen_string_literal: true

require "declare_schema"
require "declare_schema/schema_change/all"
require "declare_schema/schema_change/column_remove"
require "generators/declare_schema/migration/migrator"
require "erb"

namespace :declare_schema do
  desc 'Generate migrations for the database schema'
  task :generate => 'db:load_config' do
    up, down = Generators::DeclareSchema::Migration::Migrator.new(renames: {}).generate

    if up.blank?
      puts "Database and models match -- nothing to change"
      return
    end

    puts "\n---------- Up Migration ----------"
    puts up
    puts "----------------------------------"

    puts "\n---------- Down Migration --------"
    puts down
    puts "----------------------------------"

    migration_root_directory = "db/migrate"

    final_migration_name = Generators::DeclareSchema::Migration::Migrator.default_migration_name(Dir["#{migration_root_directory}/*declare_schema_migration*"])
    migration_template   = ERB.new(File.read(File.expand_path("../generators/declare_schema/migration/templates/migration.rb.erb", __dir__)))

    @up = "    #{up.strip.split("\n").join("\n    ")}"
    @down = "    #{down.strip.split("\n").join("\n    ")}"
    @migration_class_name = final_migration_name.camelize

    File.write("#{migration_root_directory}/#{Time.now.to_i}_#{final_migration_name.underscore}.rb", migration_template.result(binding))
  end
end
