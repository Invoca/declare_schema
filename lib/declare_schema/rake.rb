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

    final_migration_name = default_migration_name
    migration_template   = ERB.new(<<~EOF.chomp)
      # frozen_string_literal: true
      class <%= @migration_class_name %> < (ActiveRecord::Migration[4.2])
        def self.up
      <%= @up.presence or raise "no @up given!" %>
        end
        def self.down
      <%= @down.presence or raise "no @down given!" %>
        end
      end
    EOF

    @up = "    #{up.strip.split("\n").join("\n    ")}"
    @down = "    #{down.strip.split("\n").join("\n    ")}"
    @migration_class_name = final_migration_name.camelize

    File.write("db/migrate/#{Time.now.to_i}_#{final_migration_name.underscore}.rb", migration_template.result(binding))
  end
end

def default_migration_name
  existing = Dir["db/migrate/*declare_schema_migration*"]
  max = existing.grep(/([0-9]+)\.rb$/) { Regexp.last_match(1).to_i }.max.to_i
  "declare_schema_migration_#{max + 1}"
end
