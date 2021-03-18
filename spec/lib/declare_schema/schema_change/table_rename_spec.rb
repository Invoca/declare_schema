# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_rename'

RSpec.describe DeclareSchema::SchemaChange::TableRename do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:old_name) { 'networks' }
  let(:new_name) { 'customers' }
  subject { described_class.new(old_name, new_name) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("rename_table :#{old_name}, :#{new_name}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("rename_table :#{new_name}, :#{old_name}\n")
      end
    end
  end
end
