# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/table_add'

RSpec.describe DeclareSchema::SchemaChange::TableAdd do
  include_context 'prepare test app'

  let(:table_name) { 'networks' }
  let(:fields) { [[:string, :title, limit: 255, null: false ], [:boolean, :admin, null: false]] }
  let(:create_table_options) { { id: :primary_key } }
  let(:sql_options) { '' }

  subject { described_class.new(table_name, fields, create_table_options, sql_options: sql_options) }

  describe '#up/down' do
    describe '#up' do
      it 'responds with command' do
        expect(subject.up).to eq(<<~EOS)
          create_table :networks, id: :primary_key do |t|
            t.string  :title, limit: 255, null: false
            t.boolean :admin, null: false
          end

        EOS
      end

      context 'with sql_options' do
        let(:sql_options) { 'CHARACTER SET utf8mb4' }

        it 'responds with command' do
          expect(subject.up).to eq(<<~EOS)
          create_table :networks, id: :primary_key, options: "CHARACTER SET utf8mb4" do |t|
            t.string  :title, limit: 255, null: false
            t.boolean :admin, null: false
          end

          EOS
        end
      end
    end

    describe '#down' do
      it 'responds with command' do
        expect(subject.down).to eq("drop_table :#{table_name}\n")
      end
    end
  end
end
