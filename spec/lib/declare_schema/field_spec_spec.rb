# frozen_string_literal: true

RSpec.describe DeclareSchema::Model::FieldSpec do
  let(:model) { double('model', _table_options: {}, _declared_primary_key: 'id') }
  let(:col_spec) { double('col_spec', type: :string) }

  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  describe '#initialize' do
    it 'normalizes option order' do
      subject = described_class.new(model, :price, :integer, anonymize_using: 'x', null: false, position: 0, limit: 4)
      expect(subject.options.keys).to eq([:limit, :null, :anonymize_using])
    end

    it 'raises exception on unknown field type' do
      expect do
        described_class.new(model, :location, :lat_long, position: 0)
      end.to raise_exception(::DeclareSchema::UnknownTypeError, /:lat_long not found in /)
    end
  end

  describe '#schema_attributes' do
    describe 'integer 4' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :integer, limit: 4, null: false, position: 0)
        expect(subject.schema_attributes(col_spec)).to eq(type: :integer, limit: 4, null: false)
      end
    end

    describe 'integer 8' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :integer, limit: 8, null: true, position: 2)
        expect(subject.schema_attributes(col_spec)).to eq(type: :integer, limit: 8, null: true)
      end
    end

    describe 'bigint' do
      it 'returns schema attributes' do
        subject = described_class.new(model, :price, :bigint, null: false, position: 2)
        expect(subject.schema_attributes(col_spec)).to eq(type: :integer, limit: 8, null: false)
      end
    end

    describe 'string' do
      it 'returns schema attributes (including charset/collation iff mysql)' do
        subject = described_class.new(model, :title, :string, limit: 100, null: true, charset: 'utf8mb4', position: 0)
        case current_adapter
        when 'mysql2'
          expect(subject.schema_attributes(col_spec)).to eq(type: :string, limit: 100, null: true, charset: 'utf8mb4', collation: 'utf8mb4_bin')
        else
          expect(subject.schema_attributes(col_spec)).to eq(type: :string, limit: 100, null: true)
        end
      end

      context 'MySQL only' do
        include_context 'skip unless' do
          let(:adapter) { 'mysql2' }
        end

        context 'when running on MySQL 8.0' do
          around do |spec|
            DeclareSchema.mysql_version = Gem::Version.new('8.0.21')
            spec.run
          ensure
            DeclareSchema.remove_instance_variable('@mysql_version') rescue nil # rubocop:disable Style/RescueModifier
          end

          it 'normalizes charset and collation' do
            subject = described_class.new(model, :title, :string, limit: 100, null: true, charset: 'utf8', collation: 'utf8_general', position: 0)

            expect(subject.schema_attributes(col_spec)).to eq(type: :string, limit: 100, null: true, charset: 'utf8mb3', collation: 'utf8mb3_general')
          end
        end

        it 'raises error when default_string_limit option is nil when not explicitly set in field spec' do
          expect(::DeclareSchema).to receive(:default_string_limit) { nil }
          expect do
            described_class.new(model, :title, :string, null: true, charset: 'utf8mb4', position: 0)
          end.to raise_error(/limit: must be provided for :string field/)
        end
      end
    end

    describe 'text' do
      it 'returns schema attributes (including charset/collation iff mysql)' do
        subject = described_class.new(model, :title, :text, limit: 200, null: true, charset: 'utf8mb4', position: 2)
        if current_adapter == 'mysql2'
          expect(subject.schema_attributes(col_spec)).to eq(type: :text, limit: 255, null: true, charset: 'utf8mb4', collation: 'utf8mb4_bin')
        else
          expect(subject.schema_attributes(col_spec)).to eq(type: :text, null: true)
        end
      end

      it 'allows a default to be set unless mysql' do
        if current_adapter == 'mysql2'
          expect do
            described_class.new(model, :title, :text, limit: 200, null: true, default: 'none', charset: 'utf8mb4', position: 2)
          end.to raise_exception(DeclareSchema::MysqlTextMayNotHaveDefault)
        else
          subject = described_class.new(model, :title, :text, limit: 200, null: true, default: 'none', charset: 'utf8mb4', position: 2)
          expect(subject.schema_attributes(col_spec)).to eq(type: :text, null: true, default: 'none')
        end
      end

      describe 'limit' do
        it 'uses default_text_limit option when not explicitly set in field spec' do
          allow(::DeclareSchema).to receive(:default_text_limit) { 100 }
          subject = described_class.new(model, :title, :text, null: true, charset: 'utf8mb4', position: 2)
          if current_adapter == 'mysql2'
            expect(subject.schema_attributes(col_spec)).to eq(type: :text, limit: 255, null: true, charset: 'utf8mb4', collation: 'utf8mb4_bin')
          else
            expect(subject.schema_attributes(col_spec)).to eq(type: :text, null: true)
          end
        end

        it 'raises error when default_text_limit option is nil when not explicitly set in field spec' do
          if current_adapter == 'mysql2'
            expect(::DeclareSchema).to receive(:default_text_limit) { nil }
            expect do
              described_class.new(model, :title, :text, null: true, charset: 'utf8mb4', position: 2)
            end.to raise_error(/limit: must be provided for :text field/)
          end
        end
      end
    end

    describe 'enum' do
      before do
        allow(::DeclareSchema::Model::Column).to receive(:native_types).and_wrap_original do |m, *_args|
          result = m.call
          if result.has_key?(:enum)
            result
          else
            result.merge(enum: { name: "enum" })
          end
        end
      end

      describe 'default' do
        it 'allows default of nil or a Symbol' do
          [nil, :first].each do |default|
            expect do
              subject = described_class.new(model, :status, :enum, limit: [:first, :second, :third], default: default, null: false, position: 2)
              expect(subject.default).to eq(default)
            end.to_not raise_exception
          end
        end

        it 'raises ArgumentError if default is not nil or a Symbol' do
          ["first", 1].each do |default|
            expect do
              described_class.new(model, :status, :enum, limit: [:first, :second, :third], default: default, null: false, position: 2)
            end.to raise_exception(ArgumentError, /enum default: must be nil or a Symbol; got #{Regexp.escape(default.inspect)}/)
          end
        end
      end

      describe 'limit' do
        it 'raises ArgumentError if any of the limit values are not Symbols' do
          [['first', 'second', 'third'], [1, 2, 3], nil, []].each do |limit|
            expect do
              described_class.new(model, :status, :enum, limit: limit, null: false, position: 2)
            end.to raise_exception(ArgumentError, /enum limit: must be an array of 1 or more Symbols; got #{Regexp.escape(limit.inspect)}/)
          end
        end
      end
    end

    context 'MySQL only' do
      include_context 'skip unless' do
        let(:adapter) { 'mysql2' }
      end

      describe 'varbinary' do # TODO: :varbinary is an Invoca addition to Rails; make it a configurable option
        it 'is supported' do
          subject = described_class.new(model, :binary_dump, :varbinary, limit: 200, null: false, position: 2)
          expect(subject.schema_attributes(col_spec)).to eq(type: :varbinary, limit: 200, null: false)
        end
      end
    end

    describe 'decimal' do
      it 'allows precision: and scale:' do
        subject = described_class.new(model, :quantity, :decimal, precision: 8, scale: 10, null: true, position: 3)
        expect(subject.schema_attributes(col_spec)).to eq(type: :decimal, precision: 8, scale: 10, null: true)
      end

      it 'requires precision:' do
        expect_any_instance_of(described_class).to receive(:warn).with(/precision: required for :decimal type/)
        described_class.new(model, :quantity, :decimal, scale: 10, null: true, position: 3)
      end

      it 'requires scale:' do
        expect_any_instance_of(described_class).to receive(:warn).with(/scale: required for :decimal type/)
        described_class.new(model, :quantity, :decimal, precision: 8, null: true, position: 3)
      end
    end

    [:integer, :bigint, :string, :text, :binary, :datetime, :date, :time, :varbinary].compact.each do |t|
      describe t.to_s do
        let(:extra) { t == :string ? { limit: 100 } : {} }

        around do |spec|
          if t == :varbinary && current_adapter != 'mysql2'
            spec.skip
          else
            spec.run
          end
        end

        it 'does not allow precision:' do
          expect_any_instance_of(described_class).to receive(:warn).with(/precision: only allowed for :decimal type/)
          described_class.new(model, :quantity, t, **{ precision: 8, null: true, position: 3 }.merge(extra))
        end unless t == :datetime

        it 'does not allow scale:' do
          expect_any_instance_of(described_class).to receive(:warn).with(/scale: only allowed for :decimal type/)
          described_class.new(model, :quantity, t, **{ scale: 10, null: true, position: 3 }.merge(extra))
        end
      end
    end

    describe 'datetime' do
      it 'keeps type as "datetime"' do
        subject = described_class.new(model, :created_at, :datetime, null: false, position: 1)
        expect(subject.schema_attributes(col_spec)).to eq(type: :datetime, null: false)
      end
    end

    describe 'timestamp' do
      it 'normalizes type to "datetime"' do
        subject = described_class.new(model, :created_at, :timestamp, null: true, position: 2)
        expect(subject.schema_attributes(col_spec)).to eq(type: :datetime, null: true)
      end
    end

    describe 'default:' do
      let(:col_spec) { double('col_spec', type: :integer) }

      it 'typecasts default value' do
        allow(col_spec).to receive(:type_cast_from_database) { |default| Integer(default) }
        subject = described_class.new(model, :price, :integer, limit: 4, default: '42', null: true, position: 2)
        expect(subject.schema_attributes(col_spec)).to eq(type: :integer, limit: 4, default: 42, null: true)
      end
    end
  end

  describe '#schema_attributes' do
    let(:col_spec) do
      sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "integer(8)", type: :integer, limit: 8)
      ActiveRecord::ConnectionAdapters::Column.new("price", nil, sql_type_metadata, false, "adverts")
    end

    it 'returns the attributes except name, position, and non-SQL options' do
      subject = described_class.new(model, :price, :bigint, null: true, default: 0, ruby_default: -> { }, encrypt_using: -> { }, position: 2)
      expect(subject.schema_attributes(col_spec)).to eq(type: :integer, limit: 8, null: true, default: 0)
    end

    it 'aliases :bigint and :integer limit: 8' do
      int8 = described_class.new(model, :price, :integer, limit: 8, null: false, position: 0)
      bigint = described_class.new(model, :price, :bigint,          null: false, position: 0)

      expected_attributes = { type: :integer, limit: 8, null: false }
      expect(int8.schema_attributes(col_spec)).to eq(expected_attributes)
      expect(bigint.schema_attributes(col_spec)).to eq(expected_attributes)
    end
  end

  describe '#sql_options' do
    subject { described_class.new(model, :price, :integer, limit: 4, null: true, default: 0, position: 2, encrypt_using: ->(field) { field }) }
    it 'excludes non-sql options' do
      expect(subject.sql_options).to eq(limit: 4, null: true, default: 0)
    end

    describe 'null' do
      subject { described_class.new(model, :price, :integer, limit: 4, default: 0, position: 2, encrypt_using: ->(field) { field }) }
      it 'uses default_null option when not explicitly set in field spec' do
        expect(subject.sql_options).to eq(limit: 4, null: false, default: 0)
      end

      it 'raises error if default_null is set to nil when not explicitly set in field spec' do
        expect(::DeclareSchema).to receive(:default_null) { nil }
        expect { subject.sql_options }.to raise_error(/null: must be provided for field/)
      end
    end
  end
end
