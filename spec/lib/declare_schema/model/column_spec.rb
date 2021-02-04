# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/column'

RSpec.describe DeclareSchema::Model::Column do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  describe 'class methods' do
    describe '.native_type?' do
      if defined?(Mysql2)
        let(:native_types) { [:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean, :json] }
      else
        let(:native_types) { [:string, :text, :integer, :float, :decimal, :datetime, :time, :date, :binary, :boolean] }
      end

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
    end

    describe '.native_types' do
      subject { described_class.native_types }

      it 'returns the native type for :primary_key' do
        expect(subject[:primary_key]).to match(/auto_increment PRIMARY KEY|PRIMARY KEY AUTOINCREMENT NOT NULL/)
      end

      it 'returns the native type for :string' do
        expect(subject.dig(:string, :name)).to eq('varchar')
      end

      it 'returns the native type for :integer' do
        expect(subject.dig(:integer, :name)).to match(/int/)
      end

      it 'returns the native type for :datetime' do
        expect(subject.dig(:datetime, :name)).to eq('datetime')
      end
    end

    describe '.sql_type' do
      it 'returns the sql type for :string' do
        expect(described_class.sql_type(:string)).to eq(:string)
      end

      it 'returns the sql type for :integer' do
        expect(described_class.sql_type(:integer)).to match(:integer)
      end

      it 'returns the sql type for :datetime' do
        expect(described_class.sql_type(:datetime)).to eq(:datetime)
      end

      it 'raises UnknownSqlType' do
        expect do
          described_class.sql_type(:email)
        end.to raise_exception(::DeclareSchema::UnknownSqlTypeError, /:email for type :email/)
      end
    end

    describe '.deserialize_default_value' do
      require 'rails'

      if ::Rails::VERSION::MAJOR >= 5
        it 'deserializes :boolean' do
          expect(described_class.deserialize_default_value(nil, :boolean, 'true')).to eq(true)
          expect(described_class.deserialize_default_value(nil, :boolean, 'false')).to eq(false)
        end

        it 'deserializes :integer' do
          expect(described_class.deserialize_default_value(nil, :integer, '12')).to eq(12)
        end

        it 'deserializes :json' do
          expect(described_class.deserialize_default_value(nil, :json, '{}')).to eq({})
        end
      end
    end
  end

  describe 'instance methods' do
    before do
      class ColumnTestModel < ActiveRecord::Base
        fields do
          title :string, limit: 127, null: false
          count :integer, null: false
        end
      end
    end
    let(:model) { ColumnTestModel }
    let(:current_table_name) { model.table_name }
    let(:column) { double("ActiveRecord Column",
                          name: 'count',
                          type: :integer,
                          limit: nil,
                          precision: nil,
                          scale: nil,
                          type_cast_from_database: nil,
                          null: false,
                          default: nil,
                          sql_type_metadata: {}) }
    subject { described_class.new(model, current_table_name, column) }

    describe '#sql_type' do
      it 'returns sql type' do
        expect(subject.sql_type).to match(/int/)
      end
    end

    describe '#schema_attributes' do
      it 'returns a hash with relevant key/values' do
        if defined?(Mysql2)
          expect(subject.schema_attributes).to eq(type: :integer, null: false, limit: 4)
        else
          expect(subject.schema_attributes).to eq(type: :integer, null: false)
        end
      end
    end
  end
end
