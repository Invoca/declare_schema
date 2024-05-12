# frozen_string_literal: true

require 'json'
require 'open-uri'

MIN_RAILS_VERSION = Gem::Version.new('6.1.0')
DB_ADAPTERS = {
  sqlite3: '~> 1.4',
  mysql2:  '~> 0.5',
}.freeze

rails_versions_to_test = Set.new

URI.parse('https://rubygems.org/api/v1/versions/rails.json').open do |raw_version_data|
  JSON.parse(raw_version_data.read).each do |version_data|
    version = Gem::Version.new(version_data['number'])

    rails_versions_to_test << version.segments[0..1].join('.') if version >= MIN_RAILS_VERSION && !version.prerelease?
  end
end

rails_versions_to_test.each do |version|
  DB_ADAPTERS.each do |adapter, adapter_version|
    appraise "rails-#{version.gsub('.', '_')}-#{adapter}" do
      gem 'rails', "~> #{version}.0"
      remove_gem 'sqlite3' # To make sure that the adapter only exists when we're testing against sqlite3
      gem adapter, adapter_version
    end
  end
end
