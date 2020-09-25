doctest: prepare testapp environment
doctest_require: 'prepare_testapp'

doctest: generate declare_schema:model
>> begin; Rails::Generators.invoke 'declare_schema:model', %w(alpha/beta one:string two:integer); rescue => ex; $stderr.puts "#{ex.class}: #{ex}\n#{ex.backtrace.join("\n")}"; end


doctest: model file exists
>> File.exist? 'app/models/alpha/beta.rb'
=> true

doctest: model content matches
>> File.read 'app/models/alpha/beta.rb'
=> "class Alpha::Beta < #{Rails::VERSION::MAJOR > 4 ? 'ApplicationRecord' : 'ActiveRecord::Base'}\n\n  fields do\n    one :string, limit: 255\n    two :integer\n  end\n\nend\n"

doctest: module file exists
>> File.exist? 'app/models/alpha.rb'
=> true

doctest: module content matches
>> File.read 'app/models/alpha.rb'
=> "module Alpha\n  def self.table_name_prefix\n    'alpha_'\n  end\nend\n"


doctest: test file exists
>> File.exist? 'test/models/alpha/beta_test.rb'
=> true

doctest: test content matches
>> File.read 'test/models/alpha/beta_test.rb'
=>
require 'test_helper'

class Alpha::BetaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

doctest: fixture file exists
>> File.exist? 'test/fixtures/alpha/beta.yml'
=> true


doctest: generate declare_schema:migration
>> puts "#{Rails.root}/app/models/alpha.rb"
>> require "#{Rails.root}/app/models/alpha.rb" if Rails::VERSION::MAJOR > 4
>> require "#{Rails.root}/app/models/alpha/beta.rb" if Rails::VERSION::MAJOR > 4
>> Rails::Generators.invoke 'declare_schema:migration', %w(-n -m)

doctest: schema.rb file exists
>> system("ls -al db")
>> File.exist? 'db/schema.rb'
=> true

doctest: db file exists
>> File.exist?("db/development.sqlite3") || File.exist?("db/test.sqlite3")
=> true

doctest: Alpha::Beta class exists
>> Alpha::Beta
# will error if class doesn't exist
