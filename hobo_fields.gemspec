name = File.basename( __FILE__, '.gemspec' )
version = File.read(File.expand_path('VERSION', __dir__)).strip
require 'date'

Gem::Specification.new do |s|
  s.authors = ['Invoca Development after Tom Locke']
  s.email = 'development@invoca.com'
  s.homepage = 'https://github.com/Invoca/hobo_fields'
  s.summary = 'Database migration generator for Rails'
  s.description = 'Database migration generator for Rails'
  s.name = name
  s.version = version
  s.date = Date.today.to_s

  s.metadata = {
    "allowed_push_host" => "https://gem.fury.io/invoca"
  }

  s.executables = ["hobofields"]
  s.files = `git ls-files -x #{name}/* -z`.split("\0")

  s.required_rubygems_version = ">= 1.3.6"
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]

  s.add_dependency 'invoca-utils', '~> 0.4'
end

