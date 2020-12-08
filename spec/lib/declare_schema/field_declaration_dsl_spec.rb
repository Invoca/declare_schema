# frozen_string_literal: true

require_relative '../../../lib/declare_schema/field_declaration_dsl'

RSpec.describe DeclareSchema::FieldDeclarationDsl do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)

    # Currently tests are run against sqlite which only has support for binary, nocase, and rtrim collation
    Generators::DeclareSchema::Migration::Migrator.default_collation = :binary

    class TestModel < ActiveRecord::Base
      fields do
        name :string, limit: 127

        timestamps
      end
    end
  end

  after { Generators::DeclareSchema::Migration::Migrator.default_collation = Generators::DeclareSchema::Migration::Migrator::DEFAULT_COLLATION }

  let(:model) { TestModel.new }
  subject { declared_class.new(model) }

  it 'has fields' do
    expect(TestModel.field_specs).to be_kind_of(Hash)
    expect(TestModel.field_specs.keys).to eq(['name', 'created_at', 'updated_at'])
    expect(TestModel.field_specs.values.map(&:type)).to eq([:string, :datetime, :datetime])
  end

  it 'stores limits' do
    expect(TestModel.field_specs['name'].limit).to eq(127)
  end

  # TODO: fill out remaining tests
end
