# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

TESTAPP_PATH = ENV['TESTAPP_PATH'] || File.join(Dir.tmpdir, 'declare_schema_testapp') unless defined?(TESTAPP_PATH)
FileUtils.chdir(TESTAPP_PATH)

system "rm -rf app/models/ad* app/models/alpha*"
system "rm -rf test/models/ad* test/models/alpha*"
system "rm -rf test/fixtures/ad* test/fixtures/alpha*"
system "rm -rf db/migrate/*"
system "mkdir -p #{TESTAPP_PATH}/app/assets/config"
system "echo '' >> #{TESTAPP_PATH}/app/assets/config/manifest.js"

require "#{TESTAPP_PATH}/config/environment"

require 'rails/generators'
Rails::Generators.configure!(Rails.application.config.generators)

ActiveRecord::Base.connection.schema_cache.clear!

(ActiveRecord::Base.connection.tables - Generators::DeclareSchema::Migration::Migrator.always_ignore_tables).each do |table|
  ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0") rescue nil # rubocop:disable Style/RescueModifier
  ActiveRecord::Base.connection.execute("DROP TABLE #{ActiveRecord::Base.connection.quote_table_name(table)} #{current_adapter != 'sqlite3' ? 'CASCADE': ''}")
  ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1") rescue nil # rubocop:disable Style/RescueModifier
end

ActiveRecord::Base.send(:descendants).each do |model|
  unless model.name['Active'] || model.name['Application']
    nuke_model_class(model)
  end
end
