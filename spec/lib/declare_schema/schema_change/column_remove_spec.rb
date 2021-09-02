# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/column_remove'

RSpec.describe DeclareSchema::SchemaChange::ColumnRemove do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'networks' }
  let(:column_name) { 'title' }
  let(:column_type) { :integer }
  let(:column_options) { { limit: 8 } }
  let(:column_options_string) { "limit: 8" }
  subject { described_class.new(table_name, column_name, column_type, **column_options) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq("remove_column :#{table_name}, :#{column_name}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("add_column :#{table_name}, :#{column_name}, :#{column_type}, #{column_options_string}\n")
      end
    end
  end
end
