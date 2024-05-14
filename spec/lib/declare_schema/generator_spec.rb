# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  it "generates nested models" do
    generate_model 'alpha/beta', 'one:string', 'two:integer'

    expect_model_definition_to_eq('alpha/beta', <<~EOS)
      class Alpha::Beta < #{active_record_base_class}

        declare_schema do
          string  :one, limit: 255
          integer :two
        end

      end
    EOS

    expect_model_definition_to_eq('alpha', <<~EOS)
      module Alpha
        def self.table_name_prefix
          #{ActiveSupport::VERSION::MAJOR >= 7 ? '"alpha_"' : "'alpha_'"}
        end
      end
    EOS

    expect_test_definition_to_eq('alpha/beta', <<~EOS)
      require "test_helper"

      class Alpha::BetaTest < ActiveSupport::TestCase
        # test "the truth" do
        #   assert true
        # end
      end
    EOS

    expect_test_fixture_to_eq('alpha/beta', <<~EOS)
      # Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

      # This model initially had no columns defined. If you add columns to the
      # model remove the #{ActiveSupport::VERSION::MAJOR >= 7 ? '"{}"' : "'{}'"} from the fixture names and add the columns immediately
      # below each fixture, per the syntax in the comments below
      #
      one: {}
      # column: value
      #
      two: {}
      # column: value
    EOS

    $LOAD_PATH << "#{TESTAPP_PATH}/app/models"

    expect(system("bundle exec rails generate declare_schema:migration -n -m")).to be_truthy

    expect(File.exist?('db/schema.rb')).to be_truthy

    if defined?(SQLite3)
      if ActiveSupport.version >= Gem::Version.new('7.1.0')
        expect(File.exist?("storage/development.sqlite3") || File.exist?("storage/test.sqlite3")).to be_truthy
      else
        expect(File.exist?("db/development.sqlite3") || File.exist?("db/test.sqlite3")).to be_truthy
      end
    end

    module Alpha; end
    require 'alpha/beta'

    expect { Alpha::Beta }.to_not raise_exception
  end
end
