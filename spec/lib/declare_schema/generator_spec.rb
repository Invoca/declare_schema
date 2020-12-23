# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  it "generates nested models" do
    generate_model 'alpha/beta', 'one:string', 'two:integer'

    expect_model_definition_to_eq('alpha/beta', <<~EOS)
      class Alpha::Beta < #{active_record_base_class}

        fields do
          one :string, limit: 255
          two :integer
        end

      end
    EOS

    expect_model_definition_to_eq('alpha', <<~EOS)
      module Alpha
        def self.table_name_prefix
          'alpha_'
        end
      end
    EOS

    case Rails::VERSION::MAJOR
    when 4, 5
      expect_test_definition_to_eq('alpha/beta', <<~EOS)
        require 'test_helper'

        class Alpha::BetaTest < ActiveSupport::TestCase
          # test "the truth" do
          #   assert true
          # end
        end
      EOS
    else
      expect_test_definition_to_eq('alpha/beta', <<~EOS)
        require 'test_helper'

        class Alpha::BetaTest < ActiveSupport::TestCase
          # test "the truth" do
          #   assert true
          # end
        end
      EOS
    end

    case Rails::VERSION::MAJOR
    when 4
      expect_test_fixture_to_eq('alpha/beta', <<~EOS)
        # Read about fixtures at http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

        # This model initially had no columns defined.  If you add columns to the
        # model remove the '{}' from the fixture names and add the columns immediately
        # below each fixture, per the syntax in the comments below
        #
        one: {}
        # column: value
        #
        two: {}
        #  column: value
      EOS
    when 5
      expect_test_fixture_to_eq('alpha/beta', <<~EOS)
        # Read about fixtures at http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

        # This model initially had no columns defined. If you add columns to the
        # model remove the '{}' from the fixture names and add the columns immediately
        # below each fixture, per the syntax in the comments below
        #
        one: {}
        # column: value
        #
        two: {}
        # column: value
      EOS
    when 6
      expect_test_fixture_to_eq('alpha/beta', <<~EOS)
        # Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

        # This model initially had no columns defined. If you add columns to the
        # model remove the '{}' from the fixture names and add the columns immediately
        # below each fixture, per the syntax in the comments below
        #
        one: {}
        # column: value
        #
        two: {}
        # column: value
      EOS
    end

    $LOAD_PATH << "#{TESTAPP_PATH}/app/models"

    expect(system("bundle exec rails generate declare_schema:migration -n -m")).to be_truthy

    expect(File.exist?('db/schema.rb')).to be_truthy

    if defined?(SQLite3)
      expect(File.exist?("db/development.sqlite3") || File.exist?("db/test.sqlite3")).to be_truthy
    end

    module Alpha; end
    require 'alpha/beta'

    expect { Alpha::Beta }.to_not raise_exception
  end
end
