# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/column'

RSpec.describe DeclareSchema::Model::Column do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  describe 'class methods' do
    describe '.native_type?' do
      let(:native_types) { [:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :json] }

      it 'is falsey for :primary_key' do
        expect(described_class.native_type?(:primary_key)).to be_falsey
      end

      it 'is truthy for native types' do
        native_types.each do |type|
          expect(described_class.native_type?(type)).to be_truthy, type.inspect
        end
      end

      it 'is falsey for other types' do
        [:email, :url].each do |type|
          expect(described_class.native_type?(type)).to be_falsey
        end
      end

      it "is truthy when there's a NullDbAdapter (like for assets:precompile) that doesn't have any native types" do
        allow(described_class).to receive(:native_types).and_return({})
        expect(described_class.native_type?(:integer)).to be_truthy
      end
    end

    describe '.native_types' do
      subject(:native_types) { described_class.native_types }

      describe 'primary_key' do
        subject { native_types[:primary_key] }
        let(:expected_name) do
          case current_adapter
          when 'mysql2'
            'bigint auto_increment PRIMARY KEY'
          when 'postgresql'
            'bigserial primary key'
          when 'sqlite3'
            'integer PRIMARY KEY AUTOINCREMENT NOT NULL'
          end
        end
        it { is_expected.to eq(expected_name) }
      end

      describe 'string' do
        subject { native_types[:string] }
        let(:expected_name) { current_adapter == 'postgresql' ? 'character varying' : 'varchar' }
        it { is_expected.to include(name: expected_name) }
      end

      describe 'integer' do
        subject { native_types[:integer] }
        let(:expected_name) { /int/ }
        it { is_expected.to include(name: expected_name) }
      end

      describe 'datetime' do
        subject { native_types[:datetime] }
        let(:expected_name) { current_adapter == 'postgresql' ? 'timestamp' : 'datetime' }
        it { is_expected.to include(name: expected_name) }
      end
    end

    describe '.deserialize_default_value' do
      subject { described_class.deserialize_default_value(col_spec, column_type, default) }

      context 'when deserializing a boolean' do
        let(:column_type) { :boolean }
        let(:col_spec) do
          if current_adapter == 'postgresql'
            instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, type: :boolean, sql_type: "boolean", oid: 16, fmod: -1)
          else
            instance_double(ActiveRecord::ConnectionAdapters::Column, type: :boolean, sql_type: "boolean")
          end
        end

        context 'when the default is true' do
          let(:default) { 'true' }
          it { is_expected.to eq(true) }
        end

        context 'when the default is false' do
          let(:default) { 'false' }
          it { is_expected.to eq(false) }
        end
      end

      context 'when deserializing an integer' do
        let(:column_type) { :integer }
        let(:default) { '12' }
        let(:col_spec) do
          if current_adapter == 'postgresql'
            instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, type: :integer, sql_type: "integer", limit: 4, oid: 23, fmod: -1)
          else
            instance_double(ActiveRecord::ConnectionAdapters::Column, type: :integer, sql_type: "integer", limit: 4)
          end
        end

        it { is_expected.to eq(12) }
      end

      context 'when deserializing json' do
        let(:column_type) { :json }
        let(:default) { '{}' }
        let(:col_spec) do
          if current_adapter == 'postgresql'
            instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, type: :json, sql_type: "json", oid: 114, fmod: -1)
          else
            instance_double(ActiveRecord::ConnectionAdapters::Column, type: :json, sql_type: "json")
          end
        end

        it { is_expected.to eq({}) }
      end
    end
  end

  describe 'instance methods' do
    subject { described_class.new(model, current_table_name, column) }

    let(:model) { ColumnTestModel }
    let(:type) { :integer }
    let(:current_table_name) { model.table_name }
    let(:column) do
      if current_adapter == 'postgresql'
        instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column,
                        name: 'count', type: type, sql_type: type, limit: 4, precision: nil, scale: nil, null: false, default: nil,
                        oid: 23, fmod: -1)
      else
        instance_double(ActiveRecord::ConnectionAdapters::Column, name: 'count', type: type, sql_type: type, limit: nil,
                        precision: nil, scale: nil, null: false, default: nil)
      end
    end

    context 'Using declare_schema' do
      before do
        class ColumnTestModel < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock
          declare_schema do
            string :title, limit: 127, null: false
            integer :count, null: false
          end
        end
      end

      describe '#type' do
        it 'returns type' do
          expect(subject.type).to eq(type)
        end
      end

      describe '#schema_attributes' do
        it 'returns a hash with relevant key/values' do
          if current_adapter == 'sqlite3'
            expect(subject.schema_attributes).to eq(type: :integer, null: false)
          else
            expect(subject.schema_attributes).to eq(type: :integer, null: false, limit: 4)
          end
        end
      end
    end
  end
end
