# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/index_settings'

# Beware: It looks out that Rails' sqlite3 driver has bugs in retrieving indexes.
# In sqlite3/schema_statements, it skips over any index that starts with sqlite_:
#    next if row["name"].starts_with?("sqlite_")
# but this will skip over any indexes created to support "unique" column constraints.
# Fortunately this gem provides an explicit name for all indexes so it shouldn't be affected by that.

RSpec.describe DeclareSchema::Model::IndexSettings do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)

    class IndexSettingsTestModel < ActiveRecord::Base
      fields do
        name :string, limit: 127, index: true

        timestamps
      end
    end
  end

  let(:model_class) { IndexSettingsTestModel }

  describe 'instance methods' do
    let(:model) { model_class.new }
    subject { declared_class.new(model_class) }

    it 'has index_specs' do
      expect(model_class.index_specs).to be_kind_of(Array)
      expect(model_class.index_specs.map(&:name)).to eq(['on_name'])
      expect([:name, :fields, :unique].map { |attr| model_class.index_specs[0].send(attr)}).to eq(
        ['on_name', ['name'], false]
      )
    end

    it 'has index_specs_with_primary_key' do
      expect(model_class.index_specs_with_primary_key).to be_kind_of(Array)
      result = model_class.index_specs_with_primary_key.sort_by(&:name)
      expect(result.map(&:name)).to eq(['PRIMARY', 'on_name'])
      expect([:name, :fields, :unique].map { |attr| result[0].send(attr)}).to eq(
        ['PRIMARY', ['id'], true]
      )
      expect([:name, :fields, :unique].map { |attr| result[1].send(attr)}).to eq(
        ['on_name', ['name'], false]
      )
    end
  end

  describe 'class << self' do
    context 'with a migrated database' do
      before do
        ActiveRecord::Base.connection.execute <<~EOS
            CREATE TABLE index_settings_test_models (
              id INTEGER NOT NULL PRIMARY KEY,
              name TEXT NOT NULL
            )
        EOS
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE UNIQUE INDEX index_settings_test_models_on_name ON index_settings_test_models(name)
        EOS
        ActiveRecord::Base.connection.schema_cache.clear!
      end

      describe 'for_model' do
        subject { described_class.for_model(model_class) }

        it 'returns the indexes for the model' do
          expect(subject.size).to eq(2), subject.inspect
          expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
            ['index_settings_test_models_on_name', ['name'], true]
          )
          expect([:name, :columns, :unique].map { |attr| subject[1].send(attr) }).to eq(
            ['PRIMARY', ['id'], true]
          )
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
