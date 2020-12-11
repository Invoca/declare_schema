# frozen_string_literal: true

require 'active_record/connection_adapters/mysql2_adapter'
require_relative '../../../../lib/declare_schema/model/table_options_definition'

RSpec.describe DeclareSchema::Model::TableOptionsDefinition do
  before do
    load File.expand_path('../prepare_testapp.rb', __dir__)

    class TableOptionsDefinitionTestModel < ActiveRecord::Base
      fields do
        name :string, limit: 127, index: true
      end
    end
  end

  let(:model_class) { TableOptionsDefinitionTestModel }

  context 'instance methods' do
    let(:table_options) { { charset: "utf8", collation: "utf8_general"} }
    let(:model) { described_class.new('table_options_definition_test_models', table_options) }

    describe '#to_key' do
      subject { model.to_key }
      it { should eq(["table_options_definition_test_models", "{:charset=>\"utf8\", :collation=>\"utf8_general\"}"]) }
    end

    describe '#settings' do
      subject { model.settings }
      it { should eq("CHARACTER SET utf8 COLLATE utf8_general") }
    end

    describe '#hash' do
      subject { model.hash }
      it { should eq(["table_options_definition_test_models", "{:charset=>\"utf8\", :collation=>\"utf8_general\"}"].hash) }
    end

    describe '#to_s' do
      subject { model.to_s }
      it { should eq("CHARACTER SET utf8 COLLATE utf8_general") }
    end

    describe '#alter_table_statement' do
      subject { model.alter_table_statement }
      it { should eq("execute \"ALTER TABLE `table_options_definition_test_models` CHARACTER SET utf8 COLLATE utf8_general;\"") }
    end
  end


  context 'class << self' do
    describe '#for_model' do
      context 'when using a SQLite connection' do
        subject { described_class.for_model(model_class) }
        it { should eq(described_class.new(model_class.table_name, {})) }
      end
      # TODO: Convert these tests to run against a MySQL database so that we can
      #       perform them without mocking out so much
      context 'when using a MySQL connection' do
        before do
          double(ActiveRecord::ConnectionAdapters::Mysql2Adapter).tap do |stub_connection|
            expect(stub_connection).to receive(:class).and_return(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
            expect(stub_connection).to receive(:current_database).and_return('test_database')
            expect(stub_connection).to(
              receive(:select_one).with(<<~EOS)
                SELECT CCSA.character_set_name, CCSA.collation_name
                FROM information_schema.`TABLES` T, information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA
                WHERE CCSA.collation_name = T.table_collation AND T.table_schema = "test_database" AND T.table_name = "#{model_class.table_name}";
              EOS
              .and_return({ "character_set_name" => "utf8", "collation_name" => "utf8_general" })
            )
            allow(model_class).to receive(:connection).and_return(stub_connection)
          end
        end

        subject { described_class.for_model(model_class) }
        it { should eq(described_class.new(model_class.table_name, { charset: "utf8", collation: "utf8_general" })) }
      end
    end
  end
end
