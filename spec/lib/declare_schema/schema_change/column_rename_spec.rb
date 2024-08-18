# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/column_rename'

RSpec.describe DeclareSchema::SchemaChange::ColumnRename do
  include_context 'prepare test app'

  let(:table_name) { 'networks' }
  let(:old_name) { 'title' }
  let(:new_name) { 'summary' }
  subject { described_class.new(table_name, old_name, new_name) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("rename_column :#{table_name}, :#{old_name}, :#{new_name}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("rename_column :#{table_name}, :#{new_name}, :#{old_name}\n")
      end
    end
  end
end
