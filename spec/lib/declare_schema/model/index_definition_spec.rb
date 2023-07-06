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
              expect(subject.size).to eq(1), subject.inspect
              expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
                                                                                             ['PRIMARY', ['fk1_id', 'fk2_id'], true]
                                                                                         )
            end
          end

          context 'with habtm models' do
            let(:model_class) do
              DeclareSchema::Model::HabtmModelShim.new(
                'index_definition_pizzas_index_definition_toppings',
                ['index_definition_pizza_id', 'index_definition_topping_id'],
                [IndexDefinitionPizza, IndexDefinitionTopping],
                ActiveRecord::Base.connection
              )
            end

            before do
              class IndexDefinitionPizza < ActiveRecord::Base
                has_and_belongs_to_many :index_definition_toppings
              end

              class IndexDefinitionTopping < ActiveRecord::Base
                has_and_belongs_to_many :index_definition_pizzas
              end
            end

            context 'with a primary key' do
              before do
                ActiveRecord::Base.connection.execute <<~EOS
                  CREATE TABLE index_definition_pizzas_index_definition_toppings (
                    index_definition_pizza_id INTEGER NOT NULL,
                    index_definition_topping_id INTEGER NOT NULL,
                    PRIMARY KEY (index_definition_pizza_id, index_definition_topping_id)
                  )
                EOS
                ActiveRecord::Base.connection.schema_cache.clear!
              end

              it 'returns the indexes for the model' do
                expect(subject.size).to eq(1), subject.inspect
                expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) }).to eq(
                                                                                               ['PRIMARY', ['index_definition_pizza_id', 'index_definition_topping_id'], true]
                                                                                           )
              end
            end

            context 'without a primary key' do
              before do
                ActiveRecord::Base.connection.execute <<~EOS
                  CREATE TABLE index_definition_pizzas_index_definition_toppings (
                    index_definition_pizza_id INTEGER NOT NULL,
                    index_definition_topping_id INTEGER NOT NULL
                  )
                EOS
                ActiveRecord::Base.connection.execute <<~EOS
                  CREATE UNIQUE INDEX index_index_definition_pizzas_index_definition_toppings
                    ON index_definition_pizzas_index_definition_toppings(index_definition_pizza_id, index_definition_topping_id)
                EOS
                ActiveRecord::Base.connection.schema_cache.clear!
              end

              it 'returns the indexes for the model' do
                expect(subject.size).to eq(2), subject.inspect
                expect([:name, :columns, :unique].map { |attr| subject[0].send(attr) })
                  .to eq(['index_index_definition_pizzas_index_definition_toppings', ['index_definition_pizza_id', 'index_definition_topping_id'], true])
                expect([:name, :columns, :unique].map { |attr| subject[1].send(attr) })
                  .to eq(['PRIMARY', [], true])
              end
            end
          end
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
