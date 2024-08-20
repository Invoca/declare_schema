# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/column_change'

RSpec.describe DeclareSchema::SchemaChange::ColumnChange do
  include_context 'prepare test app'

  let(:table_name) { 'networks' }
  let(:column_name) { 'title' }
  let(:old_type) { :string }
  let(:old_options) { { limit: 255, null: false } }
  let(:old_options_string) { "limit: 255, null: false" }
  let(:new_type) { :text }
  let(:new_options) { { limit: 0xffff, null: true } }
  let(:new_options_string) { "limit: 65535, null: true" }
  subject { described_class.new(table_name, column_name, old_type: old_type, old_options: old_options, new_type: new_type, new_options: new_options) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("change_column :#{table_name}, :#{column_name}, :#{new_type}, #{new_options_string}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("change_column :#{table_name}, :#{column_name}, :#{old_type}, #{old_options_string}\n")
      end
    end
  end
end
