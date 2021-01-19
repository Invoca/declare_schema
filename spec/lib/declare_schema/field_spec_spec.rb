# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

RSpec.describe DeclareSchema::Model::FieldSpec do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  let(:model) { double('model', table_options: {}) }

  describe '#schema_attributes' do
    describe 'integer 4' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :integer, limit: 4, null: false, position: 0)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 4, null: false)
      end
    end

    describe 'integer 8' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :integer, limit: 8, null: true, position: 2)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 8, null: true)
      end
    end

    describe 'bigint' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :bigint, null: false, position: 2)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 8, null: false)
      end
    end

    describe 'string' do
      it 'returns schema attributes (including charset/collation iff mysql)' do
        subject = described_class.new(model, :title, :string, limit: 100, null: true, charset: 'utf8mb4', position: 0)
        if defined?(Mysql2)
          expect(subject.schema_attributes).to eq(type: :string, limit: 100, null: true, charset: 'utf8mb4', collation: 'utf8mb4_bin')
        else
          expect(subject.schema_attributes).to eq(type: :string, limit: 100, null: true)
        end
      end
    end

    describe 'text' do
      it 'returns schema attributes (including charset/collation iff mysql)' do
        subject = described_class.new(model, :title, :text, limit: 200, null: true, default: nil, charset: 'utf8mb4', position: 2)
        if defined?(Mysql2)
          expect(subject.schema_attributes).to eq(type: :text, limit: 255, null: true, default: nil, charset: 'utf8mb4', collation: 'utf8mb4_bin')
        else
          expect(subject.schema_attributes).to eq(type: :text, limit: 200, null: true, default: nil)
        end
      end

      it 'allows a default to be set unless mysql' do
        if defined?(Mysql2)
          expect do
            described_class.new(model, :title, :text, limit: 200, null: true, default: 'none', charset: 'utf8mb4', position: 2)
          end.to raise_exception(DeclareSchema::MysqlTextMayNotHaveDefault)
        else
          subject = described_class.new(model, :title, :text, limit: 200, null: true, default: 'none', charset: 'utf8mb4', position: 2)
          expect(subject.schema_attributes).to eq(type: :text, limit: 200, null: true, default: 'none')
        end
      end
    end

    describe 'datetime' do
      it 'keeps type as "datetime"' do
        subject = described_class.new(model, :created_at, :datetime, null: false, position: 1)
        expect(subject.schema_attributes).to eq(type: :datetime, null: false)
      end
    end

    describe 'timestamp' do
      it 'normalizes type to "datetime"' do
        subject = described_class.new(model, :created_at, :timestamp, null: true, position: 2)
        expect(subject.schema_attributes).to eq(type: :datetime, null: true)
      end
    end
  end

  context 'There are no model, columns to change' do
    it '#different_to should return false for int8 == int8' do
      subject = described_class.new(model, :price, :integer, limit: 8, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::Integer.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "integer(8)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "integer(8)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(col)).to eq(false)
    end

    it '#different_to should return false for bigint == bigint' do
      subject = described_class.new(model, :price, :bigint, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::BigInteger.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "bigint(20)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "bigint(20)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(col)).to eq(false)
    end

    it '#different_to should return false for int8 == bigint' do
      subject = described_class.new(model, :price, :integer, limit: 8, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::BigInteger.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "bigint(20)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "bigint(20)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(col)).to eq(false)
    end

    it '#different_to should return false for bigint == int8' do
      subject = described_class.new(model, :price, :bigint, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::Integer.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "integer(8)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "integer(8)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(col)).to eq(false)
    end
  end
end
