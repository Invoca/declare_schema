# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/index_add'

RSpec.describe DeclareSchema::SchemaChange::IndexAdd do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)
  end

  let(:table_name) { 'users' }
  let(:column_names) { [:last_name, 'first_name'] }
  let(:name) { 'on_last_name_and_first_name' }
  let(:unique) { false }
  subject { described_class.new(table_name, column_names, name: name, unique: unique) }

  describe '#up/down' do
    describe '#up' do
      context 'without where:' do
        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}\n")
        end
      end

      context 'with empty where:' do
        subject { described_class.new(table_name, column_names, name: name, unique: unique, where: nil) }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}\n")
        end
      end

      context 'with where:' do
        let(:where) { "'last_name like 'A%'" }
        subject { described_class.new(table_name, column_names, name: name, unique: unique, where: where) }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}, where: #{where.inspect}\n")
        end
      end

      context 'with unique: true' do
        let(:unique) { true }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}, unique: true\n")
        end
      end

      context 'with limit: nil' do
        let(:limit) { nil }
        subject { described_class.new(table_name, column_names, name: name, unique: unique, limit: limit) }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}\n")
        end
      end

      context 'with limit: 2' do
        let(:limit) { 2 }
        subject { described_class.new(table_name, column_names, name: name, unique: unique, limit: limit) }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}, limit: #{limit}\n")
        end
      end

      context 'with limit: hash' do
        let(:limit) { { last_name: 10, first_name: 1 } }
        subject { described_class.new(table_name, column_names, name: name, unique: unique, limit: limit) }

        it 'responds with command' do
          expect(subject.up).to eq("add_index :#{table_name}, #{column_names.map(&:to_sym).inspect}, name: #{name.to_sym.inspect}, limit: { last_name: 10, first_name: 1 }\n")
        end
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("remove_index :#{table_name}, name: #{name.to_sym.inspect}\n")
      end
    end
  end
end
