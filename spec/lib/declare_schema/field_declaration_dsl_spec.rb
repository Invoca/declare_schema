# frozen_string_literal: true

require_relative '../../../lib/declare_schema/field_declaration_dsl'

RSpec.describe DeclareSchema::FieldDeclarationDsl do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)

    class TestModel < ActiveRecord::Base
      fields do
        name :string, limit: 127

        timestamps
      end
    end
  end

  let(:model) { TestModel.new }
  subject { declared_class.new(model) }

  it 'has fields' do
    expect(TestModel.field_specs).to be_kind_of(Hash)
    expect(TestModel.field_specs.keys).to eq(['name', 'created_at', 'updated_at'])
    expect(TestModel.field_specs.values.map(&:type)).to eq([:string, :datetime, :datetime])
  end

  it 'stores limits' do
    expect(TestModel.field_specs['name'].limit).to eq(127), TestModel.field_specs['name'].inspect
  end

  # TODO: fill out remaining tests
end
