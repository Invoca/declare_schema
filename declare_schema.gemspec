# frozen_string_literal: true

require_relative 'lib/declare_schema/version'

Gem::Specification.new do |s|
  s.authors = ['Invoca Development adapted from hobo_fields by Tom Locke']
  s.email = 'development@invoca.com'
  s.homepage = 'https://github.com/Invoca/declare_schema'
  s.summary = 'Database migration generator for Rails'
  s.description = 'Declare your active_record model schemas and have database migrations generated for you!'
  s.name = "declare_schema"
  s.version = DeclareSchema::VERSION

  s.metadata = {
    "allowed_push_host" => "https://rubygems.org"
  }

  s.executables = ["declare_schema"]
  s.files = `git ls-files -x declare_schema/* -z`.split("\0")

  s.required_rubygems_version = ">= 1.3.6"
  s.require_paths = ["lib"]

  s.add_dependency 'invoca-utils', '~> 0.4'
  s.add_dependency 'rails', '>= 4.2'
end
