# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require 'rake_test_warning_false'

require 'rubygems'
require 'tmpdir'
require 'pry'

include Rake::DSL

# _ = ActiveRecord::ActiveRecordError # hack for https://rails.lighthouseapp.com/projects/8994/tickets/2577-when-using-activerecordassociations-outside-of-rails-a-nameerror-is-thrown

RUBY = 'ruby'
RUBYDOCTEST = ENV['RUBYDOCTEST'] || "#{RUBY} -S rubydoctest"

$:.unshift File.expand_path('lib', __dir__)
require 'invoca/utils'
require 'declare_schema'

GEM_ROOT = __dir__
TESTAPP_PATH = ENV['TESTAPP_PATH'] || File.join(Dir.tmpdir, 'declare_schema_testapp')
BIN = File.expand_path('bin/declare_schema', __dir__)

task default: 'test:all'

namespace "test" do
  task all: [:doctest, :unit]

  desc "Run the doctests"
  task :doctest do |t|
    files = Dir['test/*.rdoctest'].sort.map { |f| File.expand_path(f) }.join(' ')
    system("#{RUBYDOCTEST} #{files}") or exit(1)
  end

  desc "Run the unit tests"
  task :unit do |t|
    Dir["test/test_*.rb"].each do |f|
      system("#{RUBY} #{f}") or exit(1)
    end
  end

  desc "Prepare a rails application for testing"
  task :prepare_testapp, :force do |t, args|
    if args.force || !File.directory?(TESTAPP_PATH)
      FileUtils.remove_entry_secure(TESTAPP_PATH, true)
      sh %(#{BIN} new #{TESTAPP_PATH} --skip-wizard --skip-bundle)
      FileUtils.chdir TESTAPP_PATH
      sh %(bundle install)
      sh %(echo "" >> Gemfile)
      sh %(echo "gem 'irt', :group => :development" >> Gemfile) # to make the bundler happy
      sh %(echo "gem 'therubyracer'" >> Gemfile)
      sh %(echo "gem 'kramdown'" >> Gemfile)
      sh %(echo "" > app/models/.gitignore) # because git reset --hard would rm the dir
      rm %(.gitignore) # we need to reset everything in a testapp
      sh %(git init && git add . && git commit -m "initial commit")
      puts %(The testapp has been created in '#{TESTAPP_PATH}')
    else
      FileUtils.chdir TESTAPP_PATH
      sh %(git add .)
      sh %(git reset --hard -q HEAD)
    end
  end
end
