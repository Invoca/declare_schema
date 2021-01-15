# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

RSpec.describe DeclareSchema::Model::FieldSpec do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  describe '#schema_attributes' do
    context 'integer 4' do
      it 'returns schema attributes' do
        subject = described_class.new(Object, :price, :integer, limit: 4, null: false, position: 0)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 4, null: false)
      end
    end

    context 'integer 8' do
      it 'returns schema attributes' do
        subject = described_class.new(Object, :price, :integer, limit: 8, null: true, position: 2)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 8, null: true)
      end
    end

    context 'bigint' do
      it 'returns schema attributes' do
        subject = described_class.new(Object, :price, :bigint, null: false, position: 2)
        expect(subject.schema_attributes).to eq(type: :integer, limit: 8, null: false)
      end
    end

    context 'string' do
      it 'returns schema attributes' do
        subject = described_class.new(Object, :title, :string, limit: 100, null: true, position: 0)
        if defined?(Mysql2)
          expect(subject.schema_attributes).to eq(type: :string, limit: 100, null: true, charset: 'utf8', collation: 'utf8_general_ci')
        else
          expect(subject.schema_attributes).to eq(type: :string, limit: 100, null: true)
        end
      end
    end

    context 'text' do
      it 'returns schema attributes' do
        subject = described_class.new(Object, :title, :text, limit: 200, null: true, position: 2)
        if defined?(Mysql2)
          expect(subject.schema_attributes).to eq(type: :text, limit: 255, null: true, charset: 'utf8', collation: 'utf8_general_ci')
        else
          expect(subject.schema_attributes).to eq(type: :text, limit: 200, null: true)
        end
      end
    end
  end

  context 'There are no model columns to change' do
    it '#different_to should return false for int8 == int8' do
      subject = described_class.new(Object, :price, :integer, limit: 8, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::Integer.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "integer(8)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "integer(8)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(subject.name, col)).to eq(false)
    end

    it '#different_to should return false for bigint == bigint' do
      subject = described_class.new(Object, :price, :bigint, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::BigInteger.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "bigint(20)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "bigint(20)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(subject.name, col)).to eq(false)
    end

    it '#different_to should return false for int8 == bigint' do
      subject = described_class.new(Object, :price, :integer, limit: 8, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::BigInteger.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "bigint(20)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "bigint(20)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(subject.name, col)).to eq(false)
    end

    it '#different_to should return false for bigint == int8' do
      subject = described_class.new(Object, :price, :bigint, null: false, position: 0)

      case Rails::VERSION::MAJOR
      when 4
        cast_type = ActiveRecord::Type::Integer.new(limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, cast_type, "integer(8)", false)
      else
        sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "integer(8)", type: :integer, limit: 8)
        col = ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
      end

      expect(subject.different_to?(subject.name, col)).to eq(false)
    end
  end
end
