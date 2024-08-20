# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/model/table_options_definition'

RSpec.describe DeclareSchema::Model::TableOptionsDefinition do
  include_context 'prepare test app'

  let(:model_class) { TableOptionsDefinitionTestModel }
  let(:charset) { DeclareSchema.normalize_charset('utf8') }
  let(:collation) { DeclareSchema.normalize_collation('utf8_general') } # adapt so that tests will pass on MySQL 5.7 or 8+

  context 'Using declare_schema' do
    before do
      class TableOptionsDefinitionTestModel < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock
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
        it { is_expected.to eq(['table_options_definition_test_models', "{:charset=>#{charset.inspect}, :collation=>#{collation.inspect}}"]) }
      end

      describe '#settings' do
        subject { model.settings }
        it { is_expected.to eq("CHARACTER SET #{charset} COLLATE #{collation}") }

        context 'MySQL only' do
          include_context 'skip unless' do
            let(:adapter) { 'mysql2' }
          end

          context 'when running in MySQL 8' do
            around do |spec|
              DeclareSchema.mysql_version = Gem::Version.new('8.0.21')
              spec.run
            ensure
              DeclareSchema.remove_instance_variable('@mysql_version') rescue nil
            end

            it { is_expected.to eq("CHARACTER SET utf8mb3 COLLATE utf8mb3_general") }

            context 'when _ci collation' do
              let(:table_options) { { charset: "utf8", collation: "utf8_general_ci"} }
              it { is_expected.to eq("CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci") }
            end
          end
        end
      end

      describe '#hash' do
        subject { model.hash }
        it { is_expected.to eq(['table_options_definition_test_models', "{:charset=>#{charset.inspect}, :collation=>#{collation.inspect}}"].hash) }
      end

      describe '#to_s' do
        subject { model.to_s }
        it { is_expected.to eq("CHARACTER SET #{charset} COLLATE #{collation}") }
      end

      describe '#alter_table_statement' do
        subject { model.alter_table_statement }
        it { is_expected.to match(/execute "ALTER TABLE .*table_options_definition_test_models.* CHARACTER SET #{charset} COLLATE #{collation}"/) }
      end
    end

    context 'class << self' do
      describe '#for_model' do
        context 'when database migrated' do
          let(:options) do
            case current_adapter(model_class)
            when 'mysql2'
              { charset: "utf8mb4", collation: "utf8mb4_bin" }
            else
              {}
            end
          end
          subject { described_class.for_model(model_class) }

          before do
            generate_migrations '-n', '-m'
          end

          it { is_expected.to eq(described_class.new(model_class.table_name, **options)) }
        end
      end
    end
  end
end
