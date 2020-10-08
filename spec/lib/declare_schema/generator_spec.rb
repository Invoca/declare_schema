# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator' do
  let(:model_base_class) { Rails::VERSION::MAJOR > 4 ? 'ApplicationRecord' : 'ActiveRecord::Base' }

  before :all do
    load File.expand_path('prepare_testapp.rb', __dir__)
    ActiveRecord::Base.connection.execute("DROP TABLE adverts") rescue nil
    ActiveRecord::Base.connection.execute("DROP TABLE alpha_betas") rescue nil
  end

  it "generates nested models" do
    Rails::Generators.invoke('declare_schema:model', %w[alpha/beta one:string two:integer])

    expect(File.exist?('app/models/alpha/beta.rb')).to be_truthy

    expect(File.read('app/models/alpha/beta.rb')).to eq(<<~EOS)
      class Alpha::Beta < #{model_base_class}
  
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

    require "#{Rails.root}/app/models/alpha.rb"
    require "#{Rails.root}/app/models/alpha/beta.rb"
    Rails::Generators.invoke 'declare_schema:migration', %w[-n -m]

    expect(File.exist?('db/schema.rb')).to be_truthy

    expect(File.exist?("db/development.sqlite3") || File.exist?("db/test.sqlite3")).to be_truthy

    expect { Alpha::Beta }.to_not raise_exception
  end
end
