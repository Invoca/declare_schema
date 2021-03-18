# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/foreign_key_remove'

RSpec.describe DeclareSchema::SchemaChange::ForeignKeyRemove do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'users' }
  let(:parent_table_name) { 'organization' }
  let(:column_name) { :organization_id }
  let(:name) { 'on_organization_id' }
  subject { described_class.new(table_name, parent_table_name, column_name: column_name, name: name) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("remove_foreign_key :#{table_name}, name: #{name.to_sym.inspect}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("add_foreign_key :#{table_name}, :#{parent_table_name}, column: #{column_name.to_sym.inspect}, name: #{name.to_sym.inspect}\n")
      end
    end
  end
end
