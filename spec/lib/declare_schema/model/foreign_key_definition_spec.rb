# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/foreign_key_definition'

RSpec.describe DeclareSchema::Model::ForeignKeyDefinition do
  let(:model_class) { Network }

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
      let(:foreign_key_column) { :network_id }
      let(:options) { { child_table: 'networks' } }
      subject { described_class.new(foreign_key_column, **options)}

      before do
        allow(model.connection).to receive(:index_name).with(any_args) { 'index_on_network_id' }
      end

      describe '#initialize' do
        it 'normalizes symbols to strings' do
          expect(subject.foreign_key_column).to eq('network_id')
          expect(subject.parent_table_name).to eq('networks')
        end

        context 'when most options passed' do
          let(:options) { { child_table: 'networks', parent_table: :networks } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key_column).to eq('network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.foreign_key_column).to eq('network_id')
            expect(subject.constraint_name).to eq('index_networks_on_network_id')
            expect(subject.dependent).to be_nil
          end
        end

        context 'when all options passed' do
          let(:options) { { child_table: 'networks', parent_table: :networks, constraint_name: :constraint_1, dependent: :delete } }

          it 'normalizes symbols to strings' do
            expect(subject.foreign_key_column).to eq('network_id')
            expect(subject.parent_table_name).to eq('networks')
            expect(subject.constraint_name).to eq('constraint_1')
            expect(subject.dependent).to eq(:delete)
          end
        end

        context 'when constraint name passed as empty string' do
          let(:options) { { child_table: 'networks', constraint_name: "" } }

          it 'defaults to rails constraint name' do
            expect(subject.constraint_name).to eq("index_networks_on_network_id")
          end
        end

        context 'when no constraint name passed' do
          it 'defaults to rails constraint name' do
            expect(subject.constraint_name).to eq("index_networks_on_network_id")
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

      describe '.for_table' do
        subject { described_class.for_table(old_table_name, model.connection) }

        it 'returns definitions' do
          expect(subject.map(&:key)).to eq([
            ["networks", "network_id", nil]
          ])
        end
      end
    end
  end
  # TODO: fill out remaining tests
end
