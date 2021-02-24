# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end
require 'rails'
require 'rails/generators'

module Generators
  module DeclareSchema
    module Migration
      RSpec.describe Migrator do
        before do
          ActiveRecord::Base.connection.tables
        end

        subject { described_class.new }

        describe 'format_options' do
          it 'returns an array of option .inspect strings, with symbols using the modern : hash notation' do
            expect(subject.format_options({ limit: 4, 'key' => 'value "quoted"' })).to eq(["limit: 4", '"key" => "value \"quoted\""'])
          end
        end

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
            it     { should eq("utf8") }
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
        end

        describe '#default_string_limit' do
          subject { described_class.default_string_limit }

          context 'when not explicitly set' do
            it { should eq(nil) }
          end

          context 'when explicitly set' do
            before { described_class.default_string_limit = 225 }
            after  { described_class.default_string_limit = nil }
            it     { should eq(225) }
          end
        end

        describe '#default_null' do
          subject { described_class.default_null }

          context 'when not explicitly set' do
            it { should eq(false) }
          end

          context 'when explicitly set' do
            before { described_class.default_null = true }
            after  { described_class.default_null = false }
            it     { should eq(true) }
          end
        end

        describe '#default_generate_foreign_keys' do
          subject { described_class.default_generate_foreign_keys }

          context 'when not explicitly set' do
            it { should eq(true) }
          end

          context 'when explicitly set' do
            before { described_class.default_generate_foreign_keys = false }
            after  { described_class.default_generate_foreign_keys = true }
            it     { should eq(false) }
          end
        end

        describe '#default_generate_indexing' do
          subject { described_class.default_generate_indexing }

          context 'when not explicitly set' do
            it { should eq(true) }
          end

          context 'when explicitly set' do
            before { described_class.default_generate_indexing = false }
            after  { described_class.default_generate_indexing = true }
            it     { should eq(false) }
          end
        end

        describe 'load_rails_models' do
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
      end
    end
  end
end
