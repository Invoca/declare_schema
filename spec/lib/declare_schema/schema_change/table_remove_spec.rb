# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_remove'

RSpec.describe DeclareSchema::SchemaChange::TableRemove do
  include_context 'prepare test app'

  let(:table_name) { 'networks' }
  let(:add_table_back) { "create table networks(\n)" }
  subject { described_class.new(table_name, add_table_back) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("drop_table :#{table_name}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("#{add_table_back}\n\n")
      end
    end
  end
end
