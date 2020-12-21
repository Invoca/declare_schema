# frozen_string_literal: true

RSpec.describe 'DeclareSchema Model FieldSpec' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  context 'There are no model columns to change' do
    it '#different_to should return false for int8 == int8' do
      class Advert < ActiveRecord::Base
        fields do
          price :integer, limit: 8
        end
      end

      subject = DeclareSchema::Model::FieldSpec.new(Advert, :price, :integer, { limit: 8, null: false })

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
      class Advert < ActiveRecord::Base
        fields do
          price :bigint
        end
      end

      subject = DeclareSchema::Model::FieldSpec.new(Advert, :price, :bigint, { null: false })

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
      class Advert < ActiveRecord::Base
        fields do
          price :integer, limit: 8
        end
      end

      subject = DeclareSchema::Model::FieldSpec.new(Advert, :price, :integer, { limit: 8, null: false })

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
      class Advert < ActiveRecord::Base
        fields do
          price :bigint
        end
      end

      subject = DeclareSchema::Model::FieldSpec.new(Advert, :price, :bigint, { null: false })

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
