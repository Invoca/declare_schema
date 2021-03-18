# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/primary_key_change'

RSpec.describe DeclareSchema::SchemaChange::PrimaryKeyChange do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'users' }
  let(:old_column_names) { ['id'] }
  let(:new_column_names) { [:last_name, 'first_name'] }
  let(:name) { 'PRIMARY' }
  subject { described_class.new(table_name, old_column_names, new_column_names) }

  describe '#up/down' do
    context 'when PRIMARY KEY set -> set' do
      describe '#up' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} DROP PRIMARY KEY, ADD PRIMARY KEY (#{new_column_names.join(', ')})"
          expect(subject.up).to eq("execute #{command.inspect}\n")
        end
      end

      describe '#down' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} DROP PRIMARY KEY, ADD PRIMARY KEY (#{old_column_names.join(', ')})"
          expect(subject.down).to eq("execute #{command.inspect}\n")
        end
      end
    end

    context 'when PRIMARY KEY unset -> set' do
      let(:old_column_names) { nil }

      describe '#up' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} ADD PRIMARY KEY (#{new_column_names.join(', ')})"
          expect(subject.up).to eq("execute #{command.inspect}\n")
        end
      end

      describe '#down' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} DROP PRIMARY KEY"
          expect(subject.down).to eq("execute #{command.inspect}\n")
        end
      end
    end

    context 'when PRIMARY KEY set -> unset' do
      let(:new_column_names) { nil }

      describe '#up' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} DROP PRIMARY KEY"
          expect(subject.up).to eq("execute #{command.inspect}\n")
        end
      end

      describe '#down' do
        it 'responds with command' do
          command = "ALTER TABLE #{ActiveRecord::Base.connection.quote_table_name(table_name)} ADD PRIMARY KEY (#{old_column_names.join(', ')})"
          expect(subject.down).to eq("execute #{command.inspect}\n")
        end
      end
    end
  end
end
