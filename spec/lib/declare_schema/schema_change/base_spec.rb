# frozen_string_literal: true

require_relative '../../../../lib/declare_schema/schema_change/base'

RSpec.describe DeclareSchema::SchemaChange::Base do
  include_context 'prepare test app'

  before :all do
    class ChangeDefault < described_class # rubocop:disable Lint/ConstantDefinitionInBlock
      attr_reader :up_command, :down_command

      def initialize(up:, down:) # rubocop:disable Naming/MethodParameterName
        @up_command = up
        @down_command = down
      end
    end

    class ChangeOverride < described_class # rubocop:disable Lint/ConstantDefinitionInBlock
      attr_reader :up_command, :down_command

      def initialize(up:, down:) # rubocop:disable Naming/MethodParameterName
        @up_command = up
        @down_command = down
      end
    end
  end

  describe 'class methods' do
    describe 'format_options' do
      subject { { limit: 8, 'key' => 'value', subhash: { subkey: :subvalue } } }

      it 'formats using Ruby 2.0 symbol notation' do
        expect(described_class.format_options(subject)).to eq(['limit: 8', '"key" => "value"', 'subhash: { subkey: :subvalue }'])
      end
    end
  end

  describe 'instance methods' do
    describe '#up/#down' do
      context 'with single-line commands' do
        subject { ChangeDefault.new(up: "up_command", down: "down_command" )}

        describe '#up' do
          it 'responds with command and single spacing' do
            expect(subject.up).to eq("up_command\n")
          end
        end

        describe '#down' do
          it 'responds with command and single spacing' do
            expect(subject.down).to eq("down_command\n")
          end
        end
      end

      context 'with multi-line commands' do
        subject { ChangeDefault.new(up: "up_command 1\nup_command 2", down: "down_command 1\ndown_command 2" )}

        describe '#up' do
          it 'responds with command and double spacing' do
            expect(subject.up).to eq("up_command 1\nup_command 2\n\n")
          end
        end

        describe '#down' do
          it 'responds with command and spacing' do
            expect(subject.down).to eq("down_command 1\ndown_command 2\n\n")
          end
        end
      end
    end
  end
end
