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

    it 'memoizes the resolver result so repeated calls invoke it only once' do
      call_count = 0
      deferred = described_class.new(default_spec) do |_|
        call_count += 1
        mirrored_spec
      end

      3.times { deferred.resolve }

      expect(call_count).to eq(1)
    end
  end

  # Application code (e.g. ModelReport reading `field_specs[name].options[:rr_report_options]`)
  # reads from `field_specs` without first calling `.resolve`. The deferred spec must
  # therefore quack like the resolved FieldSpec; otherwise we get NoMethodError at runtime
  # in apps that read FieldSpec attributes, AND we'd return a wrong default-typed answer
  # (e.g. :bigint when the parent's PK is actually :integer or :binary).
  describe 'FieldSpec API delegation' do
    let(:deferred) { described_class.new(default_spec) { mirrored_spec } }

    it 'delegates #options to the resolved spec (parent-mirrored, not default)' do
      expect(deferred.options).to eq(mirrored_spec.options)
    end

    it 'delegates #type to the resolved spec' do
      expect(deferred.type).to eq(:string)
    end

    it 'delegates #limit to the resolved spec' do
      expect(deferred.limit).to eq(36)
    end

    it 'delegates #null to the resolved spec' do
      expect(deferred.null).to eq(false)
    end

    it 'reports respond_to? for delegated methods' do
      expect(deferred).to respond_to(:options, :type, :limit, :null, :name, :position)
    end

    it 'invokes the resolver only once across many delegated reads' do
      call_count = 0
      deferred = described_class.new(default_spec) do |_|
        call_count += 1
        mirrored_spec
      end

      deferred.options
      deferred.type
      deferred.limit
      deferred.null

      expect(call_count).to eq(1)
    end
  end
end
