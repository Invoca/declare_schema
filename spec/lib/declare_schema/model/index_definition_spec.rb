# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/index_definition'

# Beware: It looks out that Rails' sqlite3 driver has a bug in retrieving indexes.
# In sqlite3/schema_statements, it skips over any index that starts with sqlite_:
#    next if row["name"].starts_with?("sqlite_")
# but this will skip over any indexes created to support "unique" column constraints.
# This gem provides an explicit name for all indexes so it shouldn't be affected by the bug...
# unless you manually create any Sqlite tables with UNIQUE constraints.

RSpec.describe DeclareSchema::Model::IndexDefinition do
  let(:model_class) { IndexDefinitionTestModel }

  context 'Using declare_schema' do
    before do
      load File.expand_path('../prepare_testapp.rb', __dir__)

      class IndexDefinitionTestModel < ActiveRecord::Base
        declare_schema do
          string :name, limit: 127, index: true

          timestamps
        end
      end

      class IndexDefinitionCompoundIndexModel < ActiveRecord::Base
        declare_schema do
          integer :fk1_id
          integer :fk2_id

          timestamps
        end
      end
    end

    describe 'instance methods' do
      let(:model) { model_class.new }
      subject { declared_class.new(model_class) }

      it 'has index_definitions' do
        expect(model_class.index_definitions).to be_kind_of(Array)
        expect(model_class.index_definitions.map(&:name)).to eq(['index_index_definition_test_models_on_name'])
        expect([:name, :fields, :unique].map { |attr| model_class.index_definitions[0].send(attr)}).to eq(
          ['index_index_definition_test_models_on_name', ['name'], false]
        )
      end

      it 'has index_definitions_with_primary_key' do
        expect(model_class.index_definitions_with_primary_key).to be_kind_of(Array)
        result = model_class.index_definitions_with_primary_key.sort_by(&:name)
        expect(result.map(&:name)).to eq(['PRIMARY', 'index_index_definition_test_models_on_name'])
        expect([:name, :fields, :unique].map { |attr| result[0].send(attr)}).to eq(
          ['PRIMARY', ['id'], true]
        )
        expect([:name, :fields, :unique].map { |attr| result[1].send(attr)}).to eq(
          ['index_index_definition_test_models_on_name', ['name'], false]
        )
      end
    end

    context 'with a migrated database' do
      before do
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE TABLE index_definition_test_models (
            id INTEGER NOT NULL PRIMARY KEY,
            name #{if defined?(SQLite3) then 'TEXT' else 'VARCHAR(255)' end} NOT NULL
          )
        EOS
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE UNIQUE INDEX index_definition_test_models_on_name ON index_definition_test_models(name)
        EOS
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE TABLE index_definition_compound_index_models (
            fk1_id INTEGER NOT NULL,
            fk2_id INTEGER NOT NULL,
            PRIMARY KEY (fk1_id, fk2_id)
          )
        EOS
        ActiveRecord::Base.connection.schema_cache.clear!
      end

      describe 'for_model' do
        subject { described_class.for_model(model_class) }

        context 'with single-column PK' do
          it 'returns the indexes for the model' do
            expect(subject.size).to eq(2), subject.inspect
            expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
              ['index_definition_test_models_on_name', ['name'], true]
            )
            expect([:name, :columns, :unique].map { |attr| subject[1].send(attr) }).to eq(
              ['PRIMARY', ['id'], true]
            )
          end
        end

        context 'with compound-column PK' do
          let(:model_class) { IndexDefinitionCompoundIndexModel }

          it 'returns the indexes for the model' do
            expect(subject.size).to eq(1), subject.inspect
            expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
              ['PRIMARY', ['fk1_id', 'fk2_id'], true]
            )
          end
        end
      end
    end
  end

  context 'with no side effects' do
    describe '.default_index_name' do
      let(:table_name2) { 'users' }
      let(:columns2) { ['last_name', 'first_name', 'middle_name', ] }
      subject { described_class.default_index_name(table_name2, columns2) }
      around do |spec|
        orig_value = DeclareSchema.max_index_and_constraint_name_length
        DeclareSchema.max_index_and_constraint_name_length = max_index_and_constraint_name_length
        spec.run
      ensure
        DeclareSchema.max_index_and_constraint_name_length = orig_value
      end

      context 'with unlimited max_index_and_constraint_name_length' do
        let(:max_index_and_constraint_name_length) { nil }

        it { is_expected.to eq("index_users_on_last_name_and_first_name_and_middle_name") }
      end

      context 'with short max_index_and_constraint_name_length' do
        let(:max_index_and_constraint_name_length) { 40 }

        it { is_expected.to eq("users__last_name_first_name_middle_name") }
      end

      context 'with long table name' do
        let(:table_name2) { 'user_domains_extra' }
        {
          34 => '__last_name_first_name_middle_name',
          35 => 'u__last_name_first_name_middle_name',
          36 => 'u4__last_name_first_name_middle_name',
          37 => 'us4__last_name_first_name_middle_name',
          38 => 'us48__last_name_first_name_middle_name',
          39 => 'use48__last_name_first_name_middle_name',
          40 => 'use481__last_name_first_name_middle_name',
          41 => 'user481__last_name_first_name_middle_name',
          42 => 'user4814__last_name_first_name_middle_name',
          43 => 'user_4814__last_name_first_name_middle_name',
          44 => 'user_d4814__last_name_first_name_middle_name',
          45 => 'user_do4814__last_name_first_name_middle_name',
          46 => 'user_dom4814__last_name_first_name_middle_name',
          47 => 'user_doma4814__last_name_first_name_middle_name',
          48 => 'user_domai4814__last_name_first_name_middle_name',
          49 => 'user_domain4814__last_name_first_name_middle_name',
          50 => 'user_domains4814__last_name_first_name_middle_name',
          51 => 'user_domains_4814__last_name_first_name_middle_name',
          52 => 'user_domains_extra__last_name_first_name_middle_name',
          53 => 'user_domains_extra__last_name_first_name_middle_name',
        }.each do |len, index_name|
          context "with max_index_and_constraint_name_length of #{len}" do
            let(:max_index_and_constraint_name_length) { len }

            it { is_expected.to eq(index_name) }
          end
        end

        context "with max_index_and_constraint_name_length shorter than columns suffix" do
          let(:max_index_and_constraint_name_length) { 33 }

          it 'raises' do
            expect { subject }.to raise_exception(DeclareSchema::Model::IndexDefinition::IndexNameTooLongError,
                                                  /Default index name '__last_name_first_name_middle_name' exceeds configured limit of 33 characters\. Use the `name:` option to give it a shorter name, or adjust DeclareSchema\.max_index_and_constraint_name_length/i)
          end
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
