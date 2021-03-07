# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_add'

RSpec.describe DeclareSchema::SchemaChange::TableAdd do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'networks' }
  let(:create_table) { "create table networks(\n)" }
  subject { described_class.new(table_name, create_table) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("#{create_table}\n\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("drop_table :#{table_name}\n")
      end
    end
  end
end
