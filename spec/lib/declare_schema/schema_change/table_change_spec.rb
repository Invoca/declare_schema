# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_change'

RSpec.describe DeclareSchema::SchemaChange::TableChange do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'networks' }
  let(:old_options) { { charset: 'utf8', collation: 'utf8_ci' } }
  let(:new_options) { { charset: 'utf8mb4', collation: 'utf8mb4_bin' } }
  subject { described_class.new(table_name, old_options, new_options) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        statement = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
        expect(subject.up).to eq("execute #{statement.inspect}\n")
      end
    end

    describe '#down' do
      it 'responds with command' do
        statement = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} CHARACTER SET utf8 COLLATE utf8_ci"
        expect(subject.down).to eq("execute #{statement.inspect}\n")
      end
    end
  end
end
