# frozen_string_literal: true

require_relative 'lib/hobo_fields/version'

Gem::Specification.new do |s|
  s.authors = ['Invoca Development after Tom Locke']
  s.email = 'development@invoca.com'
  s.homepage = 'https://github.com/Invoca/hobo_fields'
  s.summary = 'Database migration generator for Rails'
  s.description = 'Database migration generator for Rails'
  s.name = "hobo_fields"
  s.version = HoboFields::VERSION
  s.date = "2020-07-02"

  s.metadata = {
    "allowed_push_host" => "https://gem.fury.io/invoca"
  }

  s.executables = ["hobofields"]
  s.files = `git ls-files -x hobo_fields/* -z`.split("\0")

  s.required_rubygems_version = ">= 1.3.6"
  s.require_paths = ["lib"]

  s.add_dependency 'invoca-utils', '~> 0.4'
  s.add_dependency 'rails', '>= 4.2', '< 7'
end

