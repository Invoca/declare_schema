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
            after  { described_class.default_charset = described_class::DEFAULT_CHARSET }
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
            after  { described_class.default_collation = described_class::DEFAULT_COLLATION }
            it     { should eq("utf8mb4_general_ci") }
          end
        end

        describe '#default_text_limit' do
          subject { described_class.default_text_limit }

          context 'when not explicitly set' do
            it { should eq(0xffff_ffff) }
          end

          context 'when explicitly set' do
            before { described_class.default_text_limit = 0xffff }
            after  { described_class.default_text_limit = described_class::DEFAULT_TEXT_LIMIT }
            it     { should eq(0xffff) }
          end
        end

        describe '#default_string_limit' do
          subject { described_class.default_string_limit }

          context 'when not explicitly set' do
            it { should eq(nil) }
          end

          context 'when explicitly set' do
            before { described_class.default_string_limit = 225 }
            after  { described_class.default_string_limit = described_class::DEFAULT_STRING_LIMIT }
            it     { should eq(225) }
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
