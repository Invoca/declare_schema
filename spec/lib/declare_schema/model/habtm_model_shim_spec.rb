# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

require_relative '../../../../lib/declare_schema/model/habtm_model_shim'

RSpec.describe DeclareSchema::Model::HabtmModelShim do
  let(:join_table) { "customers_users" }
  let(:foreign_keys) { ["user_id", "customer_id"] }
  let(:parent_table_names) { ["users", "customers"] }
  let(:connection) { instance_double(ActiveRecord::Base.connection.class, "connection") }

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
                                              class_name: 'Customer',
                                              klass: Customer) }
      it 'returns a new object' do
        expect(User).to receive(:connection).and_return(connection)

        result = described_class.from_reflection(reflection)

        expect(result).to be_a(described_class)
        expect(result.foreign_keys).to eq(foreign_keys.reverse)
        expect(result.parent_table_names).to eq(parent_table_names.reverse)
      end
    end
  end

  describe 'instance methods' do
    subject { described_class.new(join_table, foreign_keys, parent_table_names, connection: connection) }

    describe '#initialize' do
      it 'stores initialization attributes' do
        expect(subject.join_table).to eq(join_table)
        expect(subject.foreign_keys).to eq(foreign_keys.reverse)
      end
    end

    describe '#connection' do
      it 'returns the connection' do
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
      it 'returns false because there is no single-column PK for ActiveRecord to use' do
        expect(subject.primary_key).to eq(false)
      end
    end

    describe '#_declared_primary_key' do
      it 'returns the foreign key pair that are used as the primary key in the database' do
        expect(subject._declared_primary_key).to eq(["customer_id", "user_id"])
      end
    end

    describe '#index_definitions_with_primary_key' do
      it 'returns 2 index definitions' do
        index_definitions = subject.index_definitions_with_primary_key
        expect(index_definitions.size).to eq(2), index_definitions.inspect

        expect(index_definitions.last).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(index_definitions.last.name).to eq('PRIMARY')
        expect(index_definitions.last.fields).to eq(foreign_keys.reverse)
        expect(index_definitions.last.unique).to be_truthy
      end
    end

    context 'when table and foreign key names are long' do
      let(:join_table) { "advertiser_campaigns_tracking_pixels" }
      let(:foreign_keys_and_table_names) { [["advertiser_id", "advertisers"], ["campaign_id", "campaigns"]] }
      let(:foreign_keys) { foreign_keys_and_table_names.map(&:first) }
      let(:parent_table_names) { foreign_keys_and_table_names.map(&:last) }

      before do
        class Table1 < ActiveRecord::Base
          self.table_name = 'advertiser_campaign'
        end

        class Table2 < ActiveRecord::Base
          self.table_name = 'tracking_pixel'
        end
      end

      it 'returns two index definitions and does not raise a IndexNameTooLongError' do
        indexes = subject.index_definitions_with_primary_key.to_a
        expect(indexes.size).to eq(2), indexes.inspect
        expect(indexes.last).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(indexes.last.name).to eq('PRIMARY')
        expect(indexes.last.fields).to eq(foreign_keys)
        expect(indexes.last.unique).to be_truthy
        expect(indexes.first).to be_a(::DeclareSchema::Model::IndexDefinition)
        expect(indexes.first.name).to eq('index_advertiser_campaigns_tracking_pixels_on_campaign_id')
        expect(indexes.first.fields).to eq([foreign_keys.last])
        expect(indexes.first.unique).to be_falsey
      end
    end

    describe '#index_definitions' do
      it 'returns index_definitions' do
        indexes = subject.index_definitions
        expect(indexes.size).to eq(1), indexes.inspect
        expect(indexes.first.columns).to eq(["user_id"])
        options = [:name, :unique, :where].map { |k| [k, indexes.first.send(k)] }.to_h
        expect(options).to eq(name: "index_customers_users_on_user_id",
                              unique: false,
                              where: nil)
      end
    end

    describe '#index_definitions_with_primary_key' do
      it 'returns index_definitions_with_primary_key' do
        indexes = subject.index_definitions_with_primary_key
        expect(indexes.size).to eq(2), indexes.inspect
        expect(indexes.last.columns).to eq(["customer_id", "user_id"])
        options = [:name, :unique, :where].map { |k| [k, indexes.last.send(k)] }.to_h
        expect(options).to eq(name: "PRIMARY",
                              unique: true,
                              where: nil)
      end
    end

    describe 'ignore_indexes' do
      it 'returns empty Set' do
        expect(subject.ignore_indexes).to eq(Set.new)
      end
    end

    describe '#constraint_definitions' do
      it 'returns 2 foreign keys' do
        constraints = subject.constraint_definitions
        expect(constraints.map(&:key)).to eq([
          ["customers_users", "customer_id", :delete],
          ["customers_users", "user_id", :delete]
        ])
      end
    end
  end
end
