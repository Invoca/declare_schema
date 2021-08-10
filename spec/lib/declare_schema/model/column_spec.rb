# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

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

    describe '.deserialize_default_value' do
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

  describe 'instance methods' do
    let(:model) { ColumnTestModel }
    let(:type) { :integer }
    let(:current_table_name) { model.table_name }
    let(:column) { double("ActiveRecord Column",
                          name: 'count',
                          type: type,
                          limit: nil,
                          precision: nil,
                          scale: nil,
                          type_cast_from_database: nil,
                          null: false,
                          default: nil,
                          sql_type_metadata: {}) }
    subject { described_class.new(model, current_table_name, column) }

    context 'Using fields' do
      before do
        class ColumnTestModel < ActiveRecord::Base
          fields do
            title :string, limit: 127, null: false
            count :integer, null: false
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
          if defined?(Mysql2)
            expect(subject.schema_attributes).to eq(type: :integer, null: false, limit: 4)
          else
            expect(subject.schema_attributes).to eq(type: :integer, null: false)
          end
        end
      end
    end

    context 'Using declare_schema' do
      before do
        class ColumnTestModel < ActiveRecord::Base
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
          if defined?(Mysql2)
            expect(subject.schema_attributes).to eq(type: :integer, null: false, limit: 4)
          else
            expect(subject.schema_attributes).to eq(type: :integer, null: false)
          end
        end
      end
    end
  end
end
