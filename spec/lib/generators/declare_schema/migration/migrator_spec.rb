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
      end
    end
  end
end
