# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end
require 'rails'
require 'rails/generators'
require 'generators/declare_schema/migration/migrator'

module Generators
  module DeclareSchema
    module Migration
      RSpec.describe Migrator do
        subject { described_class.new }
        let(:charset) { ::DeclareSchema.normalize_charset('utf8') }
        let(:collation) { ::DeclareSchema.normalize_collation('utf8_general') } # adapt so that tests will pass on MySQL 5.7 or 8+

        describe '#before_generating_migration' do
          it 'requires a block be passed' do
            expect { described_class.before_generating_migration }.to raise_error(ArgumentError, 'A block is required when setting the before_generating_migration callback')
          end
        end

        describe '#default_charset' do
          subject { described_class.default_charset }

          context 'when not explicitly set' do
            it { should eq("utf8mb4") }
          end

          context 'when explicitly set' do
            before { described_class.default_charset = "utf8" }
            after  { described_class.default_charset = "utf8mb4" }
            it     { should eq(charset) }
          end

          it 'should output deprecation warning' do
            expect { described_class.default_charset = "utf8mb4" }.to output(/DEPRECATION WARNING: default_charset= is deprecated/).to_stderr
            expect { subject }.to output(/DEPRECATION WARNING: default_charset is deprecated/).to_stderr
          end
        end

        describe '#default_collation' do
          subject { described_class.default_collation }

          context 'when not explicitly set' do
            it { should eq("utf8mb4_bin") }
          end

          context 'when explicitly set' do
            before { described_class.default_collation = "utf8mb4_general_ci" }
            after  { described_class.default_collation = "utf8mb4_bin" }
            it     { should eq("utf8mb4_general_ci") }
          end

          it 'should output deprecation warning' do
            expect { described_class.default_collation = "utf8mb4_bin" }.to output(/DEPRECATION WARNING: default_collation= is deprecated/).to_stderr
            expect { subject }.to output(/DEPRECATION WARNING: default_collation is deprecated/).to_stderr
          end
        end

        describe '#load_rails_models' do
          before do
            expect(Rails.application).to receive(:eager_load!)
            expect(Rails::Engine).to receive(:subclasses).and_return([])
          end

          subject { described_class.new.load_rails_models }

          context 'when a before_generating_migration callback is configured' do
            let(:dummy_proc) { -> {} }

            before do
              described_class.before_generating_migration(&dummy_proc)
              expect(dummy_proc).to receive(:call).and_return(true)
            end

            it { should be_truthy }
          end

          context 'when no before_generating_migration callback is configured' do
            it { should be_nil }
          end
        end

        describe '#order_migrations' do
          let(:class_name_order) do
            %w[ TableRename
                TableAdd
                TableChange
                ColumnAdd
                ColumnRename
                ColumnChange
                PrimaryKeyChange
                IndexAdd
                ForeignKeyAdd
                ForeignKeyRemove
                IndexRemove
                ColumnRemove
                TableRemove ]
            end
          let(:one_of_each) do
            class_name_order.map do |class_name|
              klass = klass_from_class_name(class_name)
              instance_double(klass).tap do |double|
                allow(double).to receive(:class).and_return(klass)
              end
            end
          end
          let(:one_of_each_shuffled) { one_of_each.shuffle }

          it 'orders properly' do
            ordered = subject.order_migrations(one_of_each_shuffled)
            expect(ordered.map { |c| c.class.name.sub(/.*::/, '') }).to eq(class_name_order)
          end

          context 'when there are dups' do
            let(:one_of_each_with_dups) do
              (class_name_order * 2).map do |class_name|
                klass = klass_from_class_name(class_name)
                instance_double(klass).tap do |double|
                  allow(double).to receive(:class).and_return(klass)
                end
              end
            end
            let(:one_of_each_with_dups_shuffled) { one_of_each_with_dups.shuffle }
            let(:one_of_each_with_dups_shuffled_grouped) { one_of_each_with_dups_shuffled.group_by { |c| c.class.name } }

            it 'sorts stably' do
              ordered = subject.order_migrations(one_of_each_with_dups_shuffled)
              ordered_grouped = ordered.group_by { |c| c.class.name }
              ordered_grouped.each do |class_name, schema_changes|
                shuffled_for_class = one_of_each_with_dups_shuffled_grouped[class_name]
                expect(schema_changes.map(&:object_id)).to eq(shuffled_for_class.map(&:object_id))
              end
            end
          end
        end

        def klass_from_class_name(class_name)
          "::DeclareSchema::SchemaChange::#{class_name}".constantize
        end
      end
    end
  end
end
