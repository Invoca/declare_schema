# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

require_relative '../../../../lib/declare_schema/model/habtm_model_shim'

RSpec.describe DeclareSchema::Model::HabtmModelShim do
  let(:join_table) { "parent_1_parent_2" }
  let(:foreign_keys) { ["parent_1_id", "parent_2_id"] }
  let(:foreign_key_classes) { [Parent1, Parent2] }

  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)

    class Parent1 < ActiveRecord::Base
      self.table_name = "parent_1s"
    end

    class Parent2 < ActiveRecord::Base
      self.table_name = "parent_2s"
    end
  end

  describe 'class methods' do
    describe '.from_reflection' do
      let(:reflection) { double("reflection", join_table: join_table,
                                              foreign_key: foreign_keys.first,
                                              association_foreign_key: foreign_keys.last,
                                              active_record: foreign_key_classes.first,
                                              class_name: 'Parent1') }
      it 'returns a new object' do
        result = described_class.from_reflection(reflection)

        expect(result).to be_a(described_class)
      end
    end
  end

  describe 'instance methods' do
    let(:connection) { instance_double(ActiveRecord::Base.connection.class, "connection") }

    subject { described_class.new(join_table, foreign_keys, foreign_key_classes, connection) }

    describe '#initialize' do
      it 'stores initialization attributes' do
        expect(subject.join_table).to eq(join_table)
        expect(subject.foreign_keys).to eq(foreign_keys)
        expect(subject.foreign_key_classes).to be(foreign_key_classes)
        expect(subject.connection).to be(connection)
      end
    end

    describe '#table_options' do
      it 'returns empty hash' do
        expect(subject._table_options).to eq({})
      end
    end

    describe '#table_name' do
      it 'returns join_table' do
        expect(subject.table_name).to eq(join_table)
      end
    end

    describe '#field_specs' do
      it 'returns 2 field specs' do
        result = subject.field_specs
        expect(result.size).to eq(2), result.inspect

        expect(result[foreign_keys.first]).to be_a(::DeclareSchema::Model::FieldSpec)
        expect(result[foreign_keys.first].model).to eq(subject)
        expect(result[foreign_keys.first].name.to_s).to eq(foreign_keys.first)
        expect(result[foreign_keys.first].type).to eq(:integer)
        expect(result[foreign_keys.first].position).to eq(0)

        expect(result[foreign_keys.last]).to be_a(::DeclareSchema::Model::FieldSpec)
        expect(result[foreign_keys.last].model).to eq(subject)
        expect(result[foreign_keys.last].name.to_s).to eq(foreign_keys.last)
        expect(result[foreign_keys.last].type).to eq(:integer)
        expect(result[foreign_keys.last].position).to eq(1)
      end
    end

    describe '#primary_key' do
      it 'returns false' do
        expect(subject._declared_primary_key).to eq(false)
      end
    end

    describe '#_declared_primary_key' do
      it 'returns false' do
        expect(subject._declared_primary_key).to eq(false)
      end
    end

    describe '#index_definitions_with_primary_key' do
      it 'returns one index definition' do
        result = subject.index_definitions_with_primary_key
        expect(result.size).to eq(1), result.inspect

        expect(result.first).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(result.first.name).to eq('index_parent_1_parent_2_on_parent_1_id_parent_2_id')
        expect(result.first.fields).to eq(['parent_1_id', 'parent_2_id'])
        expect(result.first.unique).to be_truthy
      end
    end

    describe '#index_definitions' do
      it 'returns index_definitions_with_primary_key' do
        result = subject.index_definitions
        expect(result.size).to eq(1), result.inspect
      end
    end

    describe 'ignore_indexes' do
      it 'returns empty array' do
        expect(subject.ignore_indexes).to eq([])
      end
    end

    describe '#constraint_specs' do
      it 'returns 2 foreign keys' do
        result = subject.constraint_specs
        expect(result.size).to eq(2), result.inspect

        expect(result.first).to be_a(::DeclareSchema::Model::ForeignKeyDefinition)
        expect(result.first.foreign_key).to eq(foreign_keys.first)
        expect(result.first.parent_table_name).to be(Parent1.table_name)
        expect(result.first.on_delete_cascade).to be_falsey

        expect(result.last).to be_a(::DeclareSchema::Model::ForeignKeyDefinition)
        expect(result.last.foreign_key).to eq(foreign_keys.last)
        expect(result.last.parent_table_name).to be(Parent2.table_name)
        expect(result.last.on_delete_cascade).to be_falsey
      end
    end
  end
end
