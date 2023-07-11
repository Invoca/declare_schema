# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

require_relative '../../../../lib/declare_schema/model/habtm_model_shim'

RSpec.describe DeclareSchema::Model::HabtmModelShim do
  let(:join_table) { "customers_users" }
  let(:foreign_keys) { ["user_id", "customer_id"] }
  let(:table_names) { ["users", "customers"] }

  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)

    class User < ActiveRecord::Base
      self.table_name = "users"
    end

    class Customer < ActiveRecord::Base
      self.table_name = "customers"
    end
  end

  describe 'class methods' do
    describe '.from_reflection' do
      let(:reflection) { double("reflection", join_table: join_table,
                                              foreign_key: foreign_keys.first,
                                              association_foreign_key: foreign_keys.last,
                                              active_record: User,
                                              class_name: 'Customer') }
      it 'returns a new object' do
        result = described_class.from_reflection(reflection)

        expect(result).to be_a(described_class)
        expect(result.foreign_keys).to eq(foreign_keys.reverse)
        expect(result.table_names).to eq(table_names.reverse)
      end
    end
  end

  describe 'instance methods' do
    let(:connection) { instance_double(ActiveRecord::Base.connection.class, "connection") }

    subject { described_class.new(join_table, foreign_keys, table_names) }

    describe '#initialize' do
      it 'stores initialization attributes' do
        expect(subject.join_table).to eq(join_table)
        expect(subject.foreign_keys).to eq(foreign_keys.reverse)
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
        field_specs = subject.field_specs
        expect(field_specs.size).to eq(2), field_specs.inspect

        expect(field_specs[foreign_keys.first]).to be_a(::DeclareSchema::Model::FieldSpec)
        expect(field_specs[foreign_keys.first].model).to eq(subject)
        expect(field_specs[foreign_keys.first].name.to_s).to eq(foreign_keys.first)
        expect(field_specs[foreign_keys.first].type).to eq(:integer)
        expect(field_specs[foreign_keys.first].position).to eq(1)

        expect(field_specs[foreign_keys.last]).to be_a(::DeclareSchema::Model::FieldSpec)
        expect(field_specs[foreign_keys.last].model).to eq(subject)
        expect(field_specs[foreign_keys.last].name.to_s).to eq(foreign_keys.last)
        expect(field_specs[foreign_keys.last].type).to eq(:integer)
        expect(field_specs[foreign_keys.last].position).to eq(0)
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
      it 'returns 2 index definitions' do
        index_definitions = subject.index_definitions_with_primary_key
        expect(index_definitions.size).to eq(2), index_definitions.inspect

        expect(index_definitions.first).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(index_definitions.first.name).to eq('PRIMARY')
        expect(index_definitions.first.fields).to eq(foreign_keys.reverse)
        expect(index_definitions.first.unique).to be_truthy
      end
    end

    context 'when table and foreign key names are long' do
      let(:join_table) { "advertiser_campaigns_tracking_pixels" }
      let(:foreign_keys_and_table_names) { [["advertiser_id", "advertisers"], ["campaign_id", "campaigns"]] }
      let(:foreign_keys) { foreign_keys_and_table_names.map(&:first) }
      let(:table_names) { foreign_keys_and_table_names.map(&:last) }

      before do
        class Table1 < ActiveRecord::Base
          self.table_name = 'advertiser_campaign'
        end

        class Table2 < ActiveRecord::Base
          self.table_name = 'tracking_pixel'
        end
      end

      it 'returns two index definitions and does not raise a IndexNameTooLongError' do
        indexes = subject.index_definitions_with_primary_key
        expect(indexes.size).to eq(2), indexes.inspect
        expect(indexes.first).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(indexes.first.name).to eq('PRIMARY')
        expect(indexes.first.fields).to eq(foreign_keys)
        expect(indexes.first.unique).to be_truthy
        expect(indexes.last).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(indexes.last.name).to eq('index_advertiser_campaigns_tracking_pixels_on_campaign_id')
        expect(indexes.last.fields).to eq([foreign_keys.last])
        expect(indexes.last.unique).to be_falsey
      end
    end

    describe '#index_definitions' do
      it 'returns index_definitions_with_primary_key' do
        indexes = subject.index_definitions
        expect(indexes.size).to eq(2), indexes.inspect
      end
    end

    describe 'ignore_indexes' do
      it 'returns empty array' do
        expect(subject.ignore_indexes).to eq([])
      end
    end

    describe '#constraint_specs' do
      it 'returns 2 foreign keys' do
        constraints = subject.constraint_specs
        expect(constraints.size).to eq(2), constraints.inspect

        expect(constraints.first).to be_a(::DeclareSchema::Model::ForeignKeyDefinition)
        expect(constraints.first.foreign_key).to eq(foreign_keys.reverse.first)
        expect(constraints.first.parent_table_name).to be("customers")
        expect(constraints.first.on_delete_cascade).to be_truthy

        expect(constraints.last).to be_a(::DeclareSchema::Model::ForeignKeyDefinition)
        expect(constraints.last.foreign_key).to eq(foreign_keys.reverse.last)
        expect(constraints.last.parent_table_name).to be("users")
        expect(constraints.last.on_delete_cascade).to be_truthy
      end
    end
  end
end
