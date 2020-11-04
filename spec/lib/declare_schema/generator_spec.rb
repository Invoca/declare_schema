# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  it "generates nested models" do
    generate_model 'alpha/beta', 'one:string', 'two:integer'

    expect(File.exist?('app/models/alpha/beta.rb')).to be_truthy

    expect(File.read('app/models/alpha/beta.rb')).to eq(<<~EOS)
      class Alpha::Beta < #{active_record_base_class}

        fields do
          one :string, limit: 255
          two :integer
        end

      end
    EOS

    expect(File.read('app/models/alpha.rb')).to eq(<<~EOS)
      module Alpha
        def self.table_name_prefix
          'alpha_'
        end
      end
    EOS

    expect(File.read('test/models/alpha/beta_test.rb')).to eq(<<~EOS)
      require 'test_helper'

      class Alpha::BetaTest < ActiveSupport::TestCase
        # test "the truth" do
        #   assert true
        # end
      end
    EOS

    expect(File.exist?('test/fixtures/alpha/beta.yml')).to be_truthy

    $LOAD_PATH << "#{TESTAPP_PATH}/app/models"

    generate_migrations '-n', '-m'

    expect(File.exist?('db/schema.rb')).to be_truthy

    expect(File.exist?("db/development.sqlite3") || File.exist?("db/test.sqlite3")).to be_truthy

    module Alpha; end
    require 'alpha/beta'

    expect { Alpha::Beta }.to_not raise_exception
  end
end
