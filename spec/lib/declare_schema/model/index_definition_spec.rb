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
  let(:table_name) { model_class.table_name }

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

    # TODO: create model_spec.rb and move the Model specs below into it. -Colin
    describe 'instance methods' do
      let(:model) { model_class.new }
      let(:table_name) { "index_definition_test_models" }
      let(:fields) { ['last_name', 'first_name'] }
      let(:options) { { table_name: table_name } }
      subject(:instance) { described_class.new(fields, **options) }

      describe 'attr_readers' do
        describe '#table_name' do
          subject { instance.table_name }

          it { is_expected.to eq(table_name) }
        end

        describe '#fields' do
          subject { instance.fields }

          it { is_expected.to eq(fields) }
        end

        describe '#explicit_name' do
          subject { instance.explicit_name }

          context 'with allow_equivalent' do
            let(:options) { { table_name: table_name, allow_equivalent: true } }

            it { is_expected.to eq(nil) }
          end

          context 'with name option' do
            let(:options) { { table_name: table_name, name: 'index_auth_users_on_names' } }

            it { is_expected.to eq('index_auth_users_on_names') }
          end
        end

        describe '#length' do
          subject { instance.length }
          let(:options) { { table_name: table_name, length: length } }

          context 'with integer length' do
            let(:fields) { ['last_name'] }
            let(:length) { 2 }

            it { is_expected.to eq(last_name: 2) }
          end

          context 'with Hash length' do
            let(:length) { { first_name: 2 } }

            it { is_expected.to eq(length) }
          end
        end

        describe '#options' do
          subject { instance.options }
          let(:options) { { name: 'my_index', table_name: table_name, unique: false, where: "(last_name like 'a%')", length: { last_name: 10, first_name: 5 } } }

          it { is_expected.to eq(options.except(:table_name)) }
        end

        describe '#with_name' do
          subject { instance.with_name('new_name') }

          it { is_expected.to be_kind_of(described_class) }
          it { expect(instance.name).to eq('index_index_definition_test_models_on_last_name_and_first_name') }
          it { expect(subject.name).to eq('new_name') }
        end
      end
    end

    describe 'Model class methods' do
      describe '.has index_definitions' do
        subject { model_class.index_definitions }

        it 'returns indexes without primary key' do
          expect(subject.map(&:to_key)).to eq([
            ['index_index_definition_test_models_on_name', ['name'], { length: nil, unique: false, where: nil }],
          ])
        end
      end

      describe '.has index_definitions_with_primary_key' do
        subject { model_class.index_definitions_with_primary_key }

        it 'returns indexes with primary key' do
          expect(subject.map(&:to_key)).to eq([
            ['index_index_definition_test_models_on_name', ['name'], { length: nil, unique: false, where: nil }],
            ['PRIMARY', ['id'], { length: nil, unique: true, where: nil }],
          ])
        end
      end
    end

    context 'with a migrated database' do
      before do
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE TABLE index_definition_test_models (
            id INTEGER NOT NULL PRIMARY KEY,
            name #{if ActiveRecord::Base.connection_config[:adapter] == 'sqlite3' then 'TEXT' else 'VARCHAR(255)' end} NOT NULL
          )
        EOS
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE UNIQUE INDEX index_definition_test_models_on_name ON index_definition_test_models(name)
        EOS
        if ActiveRecord::Base.connection_config[:adapter] == 'mysql2'
          ActiveRecord::Base.connection.execute <<~EOS
            CREATE INDEX index_definition_test_models_on_name_partial ON index_definition_test_models(name(10))
          EOS
        end
        ActiveRecord::Base.connection.execute <<~EOS
          CREATE TABLE index_definition_compound_index_models (
            fk1_id INTEGER NOT NULL,
            fk2_id INTEGER NOT NULL,
            PRIMARY KEY (fk1_id, fk2_id)
          )
        EOS
        ActiveRecord::Base.connection.schema_cache.clear!
      end

      describe 'for_table' do
        let(:ignore_indexes) { model_class.ignore_indexes }
        subject { described_class.for_table(model_class.table_name, ignore_indexes, model_class.connection) }

        context 'with single-column PK' do
          it 'returns the indexes for the model' do
            expect(subject.map(&:to_key)).to eq([
              ["index_definition_test_models_on_name", ["name"], { unique: true, where: nil, length: nil }],
              (["index_definition_test_models_on_name_partial", ["name"], { unique: false, where: nil, length: { name: 10 } }] if ActiveRecord::Base.connection_config[:adapter] == 'mysql2'),
              ["PRIMARY", ["id"], { unique: true, where: nil, length: nil }]
            ].compact)
          end
        end

        context 'with composite (multi-column) PK' do
          let(:model_class) { IndexDefinitionCompoundIndexModel }

          it 'returns the indexes for the model' do
            expect(subject.map(&:to_key)).to eq([
              ["PRIMARY", ["fk1_id", "fk2_id"], { length: nil, unique: true, where: nil }]
            ])
          end
        end

        context 'with ignored_indexes' do
          let(:ignore_indexes) { ['index_definition_test_models_on_name'] }

          it 'skips the ignored index' do
            expect(subject.map(&:to_key)).to eq([
              (["index_definition_test_models_on_name_partial", ["name"], { unique: false, where: nil, length: { name: 10 } }] if ActiveRecord::Base.connection_config[:adapter] == 'mysql2'),
              ["PRIMARY", ["id"], { length: nil, unique: true, where: nil }]
            ].compact)
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

    describe '.normalize_index_length' do
      let(:columns) { [:last_name] }
      subject { described_class.normalize_index_length(length, columns: columns) }

      context 'with nil length' do
        let(:length) { nil }

        it { is_expected.to eq(nil) }
      end

      context 'when Integer' do
        let(:length) { 10 }

        it { is_expected.to eq(last_name: length) }

        context 'with multiple columns' do
          let(:columns) { ["last_name", "first_name"] }

          it { expect { subject }.to raise_exception(ArgumentError, /Index length of Integer only allowed when exactly one column; got 10 for \["last_name", "first_name"\]/i) }
        end
      end

      context 'when empty Hash' do
        let(:length) { {} }

        it { is_expected.to eq(nil) }
      end

      context 'when Hash' do
        let(:length) { { last_name: 10 } }

        it { is_expected.to eq(length) }
      end

      context 'when Hash with String key' do
        let(:length) { { "last_name" => 10 } }

        it { is_expected.to eq(last_name: 10) }
      end

      context 'with multiple columns' do
        let(:columns) { [:last_name, :first_name] }

        context 'when Hash with String keys' do
          let(:length) { { "last_name" => 10, "first_name" => 5 } }

          it { is_expected.to eq(last_name: 10, first_name: 5) }
        end
      end

      context 'with nil length' do
        let(:length) { nil }

        it { is_expected.to eq(nil) }
      end

      context 'with an invalid length' do
        let(:length) { 10.5 }

        it { expect { subject }.to raise_exception(ArgumentError, /length must be nil or Integer or a Hash of column names to lengths; got 10\.5 for \[:last_name\]/i) }
      end
    end
  end
  # TODO: fill out remaining tests
end
