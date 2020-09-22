# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

TESTAPP_PATH = ENV['TESTAPP_PATH'] || File.join(Dir.tmpdir, 'declare_schema_testapp')
system %(rake test:prepare_testapp TESTAPP_PATH=#{TESTAPP_PATH})
system %(echo "gem 'kramdown'" >> #{TESTAPP_PATH}/Gemfile)
system %(echo "gem 'RedCloth'" >> #{TESTAPP_PATH}/Gemfile)
FileUtils.chdir TESTAPP_PATH
system "mkdir -p #{TESTAPP_PATH}/app/assets/config"
system "echo '' >> #{TESTAPP_PATH}/app/assets/config/manifest.js"
require "#{TESTAPP_PATH}/config/environment"
require 'rails/generators'
Rails::Generators.configure!(Rails.application.config.generators)
