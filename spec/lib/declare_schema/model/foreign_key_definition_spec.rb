# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/foreign_key_definition'

RSpec.describe DeclareSchema::Model::ForeignKeyDefinition do
  let(:model_class) { Network }

  context 'Using fields' do
    before do
      load File.expand_path('../prepare_testapp.rb', __dir__)

      class Network < ActiveRecord::Base
        fields do
          name :string, limit: 127, index: true

          timestamps
        end
      end
    end

    describe 'instance methods' do
      let(:connection) { instance_double(ActiveRecord::Base.connection.class) }
      let(:model) { instance_double('Model', table_name: 'models', connection: connection) }
      let(:foreign_key) { :network_id }
      let(:options) { {} }
      subject { described_class.new(model, foreign_key, options)}

      before do
        allow(connection).to receive(:index_name).with('models', column: 'network_id') { 'on_network_id' }
      end

      describe '#initialize' do
        it 'normalizes symbols to strings' do
          expect(subject.foreign_key).to eq('network_id')
          expect(subject.parent_table_name).to eq('networks')
        end

        context 'when most options passed' do
          let(:options) { { parent_table: :networks, foreign_key: :the_network_id, index_name: :index_on_network_id } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key).to eq('network_id')
            expect(subject.foreign_key_name).to eq('the_network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.foreign_key).to eq('network_id')
            expect(subject.constraint_name).to eq('index_on_network_id')
            expect(subject.on_delete_cascade).to be_falsey
          end
        end

        context 'when all options passed' do
          let(:foreign_key) { nil }
          let(:options) { { parent_table: :networks, foreign_key: :the_network_id, index_name: :index_on_network_id,
                            constraint_name: :constraint_1, dependent: :delete } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key).to be_nil
            expect(subject.foreign_key_name).to eq('the_network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.constraint_name).to eq('constraint_1')
            expect(subject.on_delete_cascade).to be_truthy
          end
        end
      end
    end

    describe 'class << self' do
      let(:connection) { instance_double(ActiveRecord::Base.connection.class) }
      let(:model) { instance_double('Model', table_name: 'models', connection: connection) }
      let(:old_table_name) { 'networks' }
      before do
        allow(connection).to receive(:quote_table_name).with('networks') { 'networks' }
        allow(connection).to receive(:select_rows) { [['CONSTRAINT `constraint` FOREIGN KEY (`network_id`) REFERENCES `networks` (`id`)']] }
        allow(connection).to receive(:index_name).with('models', column: 'network_id') { }
      end

      describe '.for_model' do
        subject { described_class.for_model(model, old_table_name) }

        it 'returns new object' do
          expect(subject.size).to eq(1), subject.inspect
          expect(subject.first).to be_kind_of(described_class)
          expect(subject.first.foreign_key).to eq('network_id')
        end
      end
    end
  end

  context 'Using declare_schema' do
    before do
      load File.expand_path('../prepare_testapp.rb', __dir__)

      class Network < ActiveRecord::Base
        declare_schema do
          string :name, limit: 127, index: true

          timestamps
        end
      end
    end

    describe 'instance methods' do
      let(:connection) { instance_double(ActiveRecord::Base.connection.class) }
      let(:model) { instance_double('Model', table_name: 'models', connection: connection) }
      let(:foreign_key) { :network_id }
      let(:options) { {} }
      subject { described_class.new(model, foreign_key, options)}

      before do
        allow(connection).to receive(:index_name).with('models', column: 'network_id') { 'on_network_id' }
      end

      describe '#initialize' do
        it 'normalizes symbols to strings' do
          expect(subject.foreign_key).to eq('network_id')
          expect(subject.parent_table_name).to eq('networks')
        end

        context 'when most options passed' do
          let(:options) { { parent_table: :networks, foreign_key: :the_network_id, index_name: :index_on_network_id } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key).to eq('network_id')
            expect(subject.foreign_key_name).to eq('the_network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.foreign_key).to eq('network_id')
            expect(subject.constraint_name).to eq('index_on_network_id')
            expect(subject.on_delete_cascade).to be_falsey
          end
        end

        context 'when all options passed' do
          let(:foreign_key) { nil }
          let(:options) { { parent_table: :networks, foreign_key: :the_network_id, index_name: :index_on_network_id,
                            constraint_name: :constraint_1, dependent: :delete } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key).to be_nil
            expect(subject.foreign_key_name).to eq('the_network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.constraint_name).to eq('constraint_1')
            expect(subject.on_delete_cascade).to be_truthy
          end
        end
      end
    end

    describe 'class << self' do
      let(:connection) { instance_double(ActiveRecord::Base.connection.class) }
      let(:model) { instance_double('Model', table_name: 'models', connection: connection) }
      let(:old_table_name) { 'networks' }
      before do
        allow(connection).to receive(:quote_table_name).with('networks') { 'networks' }
        allow(connection).to receive(:select_rows) { [['CONSTRAINT `constraint` FOREIGN KEY (`network_id`) REFERENCES `networks` (`id`)']] }
        allow(connection).to receive(:index_name).with('models', column: 'network_id') { }
      end

      describe '.for_model' do
        subject { described_class.for_model(model, old_table_name) }

        it 'returns new object' do
          expect(subject.size).to eq(1), subject.inspect
          expect(subject.first).to be_kind_of(described_class)
          expect(subject.first.foreign_key).to eq('network_id')
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
