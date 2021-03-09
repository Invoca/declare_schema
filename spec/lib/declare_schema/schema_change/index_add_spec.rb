# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/index_add'

RSpec.describe DeclareSchema::SchemaChange::IndexAdd do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'users' }
  let(:column_names) { [:last_name, 'first_name'] }
  let(:name) { 'on_last_name_and_first_name' }
  let(:unique) { true }
  subject { described_class.new(table_name, column_names, name: name, unique: unique) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("create_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}, unique: #{unique}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("remove_index :#{table_name}, name: #{name.to_sym.inspect}\n")
      end
    end
  end
end
