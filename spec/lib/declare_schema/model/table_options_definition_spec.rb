# frozen_string_literal: true

begin
  require 'mysql2'
  require 'active_record/connection_adapters/mysql2_adapter'
rescue LoadError
end
require_relative '../../../../lib/declare_schema/model/table_options_definition'

RSpec.describe DeclareSchema::Model::TableOptionsDefinition do
  let(:model_class) { TableOptionsDefinitionTestModel }

  context 'Using declare_schema' do
    before do
      load File.expand_path('../prepare_testapp.rb', __dir__)

      class TableOptionsDefinitionTestModel < ActiveRecord::Base
        declare_schema do
          string :name, limit: 127, index: true
        end
      end
    end

    context 'instance methods' do
      let(:table_options) { { charset: "utf8", collation: "utf8_general"} }
      let(:model) { described_class.new('table_options_definition_test_models', **table_options) }

      describe '#to_key' do
        subject { model.to_key }
        it { should eq(['table_options_definition_test_models', '{:charset=>"utf8", :collation=>"utf8_general"}']) }
      end

      describe '#settings' do
        subject { model.settings }
        it { should eq("CHARACTER SET utf8 COLLATE utf8_general") }

        if defined?(Mysql2)
          context 'when running in MySQL 8' do
            around do |spec|
              DeclareSchema.mysql_version = Gem::Version.new('8.0.21')
              spec.run
            ensure
              DeclareSchema.remove_instance_variable('@mysql_version') rescue nil
            end

            it { should eq("CHARACTER SET utf8mb3 COLLATE utf8mb3_general") }

            context 'when _ci collation' do
              let(:table_options) { { charset: "utf8", collation: "utf8_general_ci"} }
              it { should eq("CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci") }
            end
          end
        end
      end

      describe '#hash' do
        subject { model.hash }
        it { should eq(['table_options_definition_test_models', '{:charset=>"utf8", :collation=>"utf8_general"}'].hash) }
      end

      describe '#to_s' do
        subject { model.to_s }
        it { should eq("CHARACTER SET utf8 COLLATE utf8_general") }
      end

      describe '#alter_table_statement' do
        subject { model.alter_table_statement }
        it { should match(/execute "ALTER TABLE .*table_options_definition_test_models.* CHARACTER SET utf8 COLLATE utf8_general"/) }
      end
    end

    context 'class << self' do
      describe '#for_model' do
        context 'when database migrated' do
          let(:options) do
            if defined?(Mysql2)
              { charset: "utf8mb4", collation: "utf8mb4_bin" }
            else
              { }
            end
          end
          subject { described_class.for_model(model_class) }

          before do
            generate_migrations '-n', '-m'
          end

          it { should eq(described_class.new(model_class.table_name, **options)) }
        end
      end
    end
  end
end
