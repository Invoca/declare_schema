# frozen_string_literal: true

require "bundler/gem_tasks"
require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require 'rubygems'
require 'tmpdir'
require 'pry'

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'declare_schema'

RUBY = 'ruby'
GEM_ROOT = __dir__
TESTAPP_PATH = ENV['TESTAPP_PATH'] || File.join(Dir.tmpdir, 'declare_schema_testapp')
BIN = File.expand_path('bin/declare_schema', __dir__)

task default: 'test:all'

include Rake::DSL

namespace "test" do
  task all: :spec

  desc "Prepare a rails application for testing"
  task :prepare_testapp, [:adapter, :force] do |_t, args|
    if args.force || !File.directory?(TESTAPP_PATH)
      FileUtils.remove_entry_secure(TESTAPP_PATH, true)
      sh %(#{BIN} new #{TESTAPP_PATH} --skip-wizard --skip-bundle --api -d #{args.adapter})
      FileUtils.chdir(TESTAPP_PATH)
      if args.adapter == 'mysql'
        sh "sed -i -e 's/host:.*/host: <%= ENV[\"MYSQL_HOST\"].presence || \"localhost\" %>/g' #{TESTAPP_PATH}/config/database.yml || echo sed failed!"
        sh "sed -i -e 's/password:.*/password: <%= ENV[\"MYSQL_PASSWORD\"].presence %>/g' #{TESTAPP_PATH}/config/database.yml || echo sed failed!"
      end
      sh "bundle install"
      sh "(echo '';
           echo \"gem 'irb', :group => :development\") >> Gemfile"
      sh "echo '' > app/models/.gitignore" # because git reset --hard would rm the dir
      rm ".gitignore" # we need to reset everything in a testapp
      sh "git init && git add . && git commit -nm \"initial commit\""
      sh "bin/rails db:create"
      puts "The testapp has been created in '#{TESTAPP_PATH}'"
    else
      FileUtils.chdir(TESTAPP_PATH)
      sh "git add ."
      sh "git reset --hard -q HEAD"
    end
  end
end
