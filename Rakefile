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
  task :prepare_testapp, :force do |_t, args|
    if args.force || !File.directory?(TESTAPP_PATH)
      FileUtils.remove_entry_secure(TESTAPP_PATH, true)
      sh %(#{BIN} new #{TESTAPP_PATH} --skip-wizard --skip-bundle)
      FileUtils.chdir(TESTAPP_PATH)
      begin
        require 'mysql2'
        if ENV['MYSQL_PORT']
          sh "(echo 'H';
               echo '1,$s/localhost/127.0.0.1/';
               echo '/host:/';
               echo 'a';
               echo '  port: #{ENV['MYSQL_PORT']}';
               echo '.';
               echo w;
               echo q) | ed #{TESTAPP_PATH}/config/database.yml || echo ed failed!"
        end
      rescue LoadError
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
