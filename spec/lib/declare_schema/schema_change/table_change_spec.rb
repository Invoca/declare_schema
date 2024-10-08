# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_change'

RSpec.describe DeclareSchema::SchemaChange::TableChange do
  include_context 'prepare test app'

  let(:table_name)     { 'networks' }
  let(:old_options)    { { charset: 'utf8', collation: 'utf8_ci' } }
  let(:new_options)    { { charset: 'utf8mb4', collation: 'utf8mb4_bin' } }
  let(:options_string) { 'CHARACTER SET utf8mb4 COLLATE utf8mb4_bin' }
  subject              { described_class.new(table_name, old_options, new_options) }

  describe '#up/down' do
    context 'when Hashes are used to construct the TableChange' do
      it 'does not raise' do
        described_class.new(table_name, old_options, new_options)
      end

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

    context 'when Strings are used to construct the TableChange' do
      context 'when old_options is a string' do
        subject { described_class.new(table_name, options_string, new_options) }

        it 'raises' do
          expect {
            subject
          }.to raise_exception(ArgumentError, /old_options must be a Hash but is: "CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"/)
        end
      end

      context 'when new_options is a string' do
        subject { described_class.new(table_name, old_options, options_string) }

        it 'raises' do
          expect {
            subject
          }.to raise_exception(ArgumentError, /new_options must be a Hash but is: "CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"/)
        end
      end
    end
  end
end
