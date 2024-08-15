# frozen_string_literal: true

require 'json'
require 'open-uri'

MIN_RAILS_VERSION = Gem::Version.new('6.1.0')

rails_versions_to_test = Set.new

URI.parse('https://rubygems.org/api/v1/versions/rails.json').open do |raw_version_data|
  JSON.parse(raw_version_data.read).each do |version_data|
    version = Gem::Version.new(version_data['number'])

    rails_versions_to_test << version.segments[0..1].join('.') if version >= MIN_RAILS_VERSION && !version.prerelease?
  end
end

rails_versions_to_test.each do |version|
  appraise "rails-#{version.gsub('.', '_')}" do
    gem 'rails', "~> #{version}.0"
  end
end
