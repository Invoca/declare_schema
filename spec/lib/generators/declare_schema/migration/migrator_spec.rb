# frozen_string_literal: true

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
          let(:mysql_longtext_limit) { 0xffff_ffff }

          context 'MySQL' do
            before do
              expect(::DeclareSchema::Model::FieldSpec).to receive(:mysql_text_limits?).and_return(true)
            end

            it 'returns text limits' do
              expect(subject.format_options({ limit: mysql_longtext_limit }, :text)).to eq(["limit: #{mysql_longtext_limit}"])
            end
          end

          context 'non-MySQL' do
            before do
              expect(::DeclareSchema::Model::FieldSpec).to receive(:mysql_text_limits?).and_return(false)
            end

            it 'returns text limits' do
              expect(subject.format_options({ limit: mysql_longtext_limit }, :text)).to eq([])
            end
          end
        end

        describe '#after_load_rails_models' do
          it 'requires a block be passed' do
            expect { described_class.after_load_rails_models }.to raise_error(ArgumentError, 'A block is required when setting the after_load_rails_models callback')
          end
        end

        describe 'load_rails_models' do
          before do
            expect(Rails.application).to receive(:eager_load!)
            expect(Rails::Engine).to receive(:subclasses).and_return([])
          end

          subject { described_class.new.load_rails_models }

          context 'when a after_load_rails_models callback is configured' do
            let(:dummy_proc) { -> {} }

            before do
              described_class.after_load_rails_models(&dummy_proc)
              expect(dummy_proc).to receive(:call).and_return(true)
            end

            it { should be_truthy }
          end

          context 'when no after_load_rails_models callback is configured' do
            it { should be_nil }
          end
        end
      end
    end
  end
end
