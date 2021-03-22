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

  context 'Using fields' do
    before do
      load File.expand_path('../prepare_testapp.rb', __dir__)

      class IndexDefinitionTestModel < ActiveRecord::Base
        fields do
          name :string, limit: 127, index: true

          timestamps
        end
      end

      class IndexDefinitionCompoundIndexModel < ActiveRecord::Base
        fields do
          fk1_id :integer
          fk2_id :integer

          timestamps
        end
      end
    end

    describe 'instance methods' do
      let(:model) { model_class.new }
      subject { declared_class.new(model_class) }

      it 'has index_definitions' do
        expect(model_class.index_definitions).to be_kind_of(Array)
        expect(model_class.index_definitions.map(&:name)).to eq(['on_name'])
        expect([:name, :fields, :unique].map { |attr| model_class.index_definitions[0].send(attr)}).to eq(
          ['on_name', ['name'], false]
        )
      end

      it 'has index_definitions_with_primary_key' do
        expect(model_class.index_definitions_with_primary_key).to be_kind_of(Array)
        result = model_class.index_definitions_with_primary_key.sort_by(&:name)
        expect(result.map(&:name)).to eq(['PRIMARY', 'on_name'])
        expect([:name, :fields, :unique].map { |attr| result[0].send(attr)}).to eq(
          ['PRIMARY', ['id'], true]
        )
        expect([:name, :fields, :unique].map { |attr| result[1].send(attr)}).to eq(
          ['on_name', ['name'], false]
        )
      end
    end

    describe 'class methods' do
      describe 'index_name' do
        it 'works with a single column' do
          expect(described_class.index_name('parent_id')).to eq('on_parent_id')
        end

        it 'works with many columns' do
          expect(described_class.index_name(['a', 'b', 'c'])).to eq('on_a_and_b_and_c')
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
              if ActiveSupport::VERSION::MAJOR < 5
                expect(model_class.connection).to receive(:primary_key).with('index_definition_compound_index_models').and_return(nil)
                connection_stub = instance_double(ActiveRecord::Base.connection.class, "connection")
                expect(connection_stub).to receive(:indexes).
                  with('index_definition_compound_index_models').
                  and_return([DeclareSchema::Model::IndexDefinition.new(model_class, ['fk1_id', 'fk2_id'], name: 'PRIMARY')])

                expect(model_class.connection).to receive(:dup).and_return(connection_stub)
              end

              expect(subject.size).to eq(1), subject.inspect
              expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
                ['PRIMARY', ['fk1_id', 'fk2_id'], true]
              )
            end
          end
        end
      end
    end
  end

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
        expect(model_class.index_definitions.map(&:name)).to eq(['on_name'])
        expect([:name, :fields, :unique].map { |attr| model_class.index_definitions[0].send(attr)}).to eq(
                                                                                                           ['on_name', ['name'], false]
                                                                                                       )
      end

      it 'has index_definitions_with_primary_key' do
        expect(model_class.index_definitions_with_primary_key).to be_kind_of(Array)
        result = model_class.index_definitions_with_primary_key.sort_by(&:name)
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
              if ActiveSupport::VERSION::MAJOR < 5
                expect(model_class.connection).to receive(:primary_key).with('index_definition_compound_index_models').and_return(nil)
                connection_stub = instance_double(ActiveRecord::Base.connection.class, "connection")
                expect(connection_stub).to receive(:indexes).
                    with('index_definition_compound_index_models').
                    and_return([DeclareSchema::Model::IndexDefinition.new(model_class, ['fk1_id', 'fk2_id'], name: 'PRIMARY')])

                expect(model_class.connection).to receive(:dup).and_return(connection_stub)
              end

              expect(subject.size).to eq(1), subject.inspect
              expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
                                                                                             ['PRIMARY', ['fk1_id', 'fk2_id'], true]
                                                                                         )
            end
          end
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
