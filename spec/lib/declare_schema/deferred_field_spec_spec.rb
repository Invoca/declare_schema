# frozen_string_literal: true

RSpec.describe DeclareSchema::Model::DeferredFieldSpec do
  include_context 'prepare test app'

  let(:model)         { double('model', _table_options: {}, _declared_primary_key: 'id') }
  let(:default_spec)  { DeclareSchema::Model::FieldSpec.new(model, :advertiser_id, :integer, limit: 8, null: false, position: 1) }
  let(:mirrored_spec) { DeclareSchema::Model::FieldSpec.new(model, :advertiser_id, :string,  limit: 36, null: false, position: 1) }

  describe '#initialize' do
    it 'requires a resolver block' do
      expect { described_class.new(default_spec) }.to raise_error(ArgumentError, /resolver block/)
    end
  end

  describe '#resolve' do
    it 'invokes the resolver with the default spec and returns its result' do
      captured = nil
      deferred = described_class.new(default_spec) do |spec|
        captured = spec
        mirrored_spec
      end

      expect(deferred.resolve).to equal(mirrored_spec)
      expect(captured).to equal(default_spec)
    end
  end
end
