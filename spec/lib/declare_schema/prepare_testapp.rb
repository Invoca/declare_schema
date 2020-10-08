# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

TESTAPP_PATH = ENV['TESTAPP_PATH'] || File.join(Dir.tmpdir, 'declare_schema_testapp')
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
