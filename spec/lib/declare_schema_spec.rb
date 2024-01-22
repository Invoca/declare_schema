# frozen_string_literal: true

RSpec.describe DeclareSchema do
  describe '#default_charset' do
    subject { described_class.default_charset }

    context 'when not explicitly set' do
      it { is_expected.to eq("utf8mb4") }
    end

    context 'when running on MySQL 5.7' do
      around do |spec|
        described_class.mysql_version = Gem::Version.new('5.7.48')
        spec.run
      ensure
        described_class.remove_instance_variable('@mysql_version') rescue nil
      end

      context 'when explicitly set' do
        before { described_class.default_charset = "utf8" }
        after  { described_class.default_charset = "utf8mb4" }
        it     { is_expected.to eq("utf8") }
      end
    end

    context 'when running on MySQL 8.0' do
      around do |spec|
        described_class.mysql_version = Gem::Version.new('8.0.21')
        spec.run
      ensure
        described_class.remove_instance_variable('@mysql_version') rescue nil
      end

      context 'when explicitly set' do
        before { described_class.default_charset = "utf8" }
        after  { described_class.default_charset = "utf8mb4" }
        it     { is_expected.to eq("utf8mb3") }
      end
    end

    context 'when MySQL version not known yet' do
      before { described_class.remove_instance_variable('@mysql_version') rescue nil }
      after { described_class.remove_instance_variable('@mysql_version') rescue nil }

      context 'when set' do
        let(:connection) { double("connection", select_value: "8.0.21") }

        it "is lazy, so it doesn't use the database connection until read" do
          @connection_called = false
          expect(ActiveRecord::Base).to receive(:connection) do
            @connection_called = true
            connection
          end
          described_class.default_charset = "utf8"
          expect(@connection_called).to eq(false)
          described_class.default_charset
          expect(@connection_called).to eq(true)
        end
      end
    end
  end

  describe '#default_collation' do
    subject { described_class.default_collation }

    context 'when not explicitly set' do
      it { is_expected.to eq("utf8mb4_bin") }
    end

    context 'when running on MySQL 5.7' do
      around do |spec|
        described_class.mysql_version = Gem::Version.new('5.7.48')
        spec.run
      ensure
        described_class.remove_instance_variable('@mysql_version')
      end

      context 'when explicitly set' do
        before { described_class.default_collation = "utf8_general_ci" }
        after  { described_class.default_collation = "utf8mb4_bin" }
        it     { is_expected.to eq("utf8_general_ci") }
      end
    end

    context 'when running on MySQL 8.0' do
      around do |spec|
        described_class.mysql_version = Gem::Version.new('8.0.21')
        spec.run
      ensure
        described_class.remove_instance_variable('@mysql_version')
      end

      context 'when explicitly set without _ci' do
        before { described_class.default_collation = "utf8_general" }
        after  { described_class.default_collation = "utf8mb4_bin" }
        it     { is_expected.to eq("utf8mb3_general") }
      end

      context 'when explicitly set with _ci' do
        before { described_class.default_collation = "utf8_general_ci" }
        after  { described_class.default_collation = "utf8mb4_bin" }
        it     { is_expected.to eq("utf8mb3_general_ci") }
      end
    end

    context 'when MySQL version not known yet' do
      before { described_class.remove_instance_variable('@mysql_version') rescue nil }
      after { described_class.remove_instance_variable('@mysql_version') rescue nil }

      context 'when set' do
        let(:connection) { double("connection", select_value: "8.0.21") }

        it "is lazy, so it doesn't use the database connection until read" do
          @connection_called = false
          expect(ActiveRecord::Base).to receive(:connection) do
            @connection_called = true
            connection
          end
          described_class.default_collation = "utf8_general_ci"
          expect(@connection_called).to eq(false)
          described_class.default_collation
          expect(@connection_called).to eq(true)
        end
      end
    end
  end

  describe '#default_text_limit' do
    subject { described_class.default_text_limit }

    context 'when not explicitly set' do
      it { is_expected.to eq(0xffff_ffff) }
    end

    context 'when explicitly set' do
      before { described_class.default_text_limit = 0xffff }
      after  { described_class.default_text_limit = 0xffff_ffff }
      it     { is_expected.to eq(0xffff) }
    end
  end

  describe '#default_string_limit' do
    subject { described_class.default_string_limit }

    context 'when not explicitly set' do
      it { is_expected.to eq(nil) }
    end

    context 'when explicitly set' do
      before { described_class.default_string_limit = 225 }
      after  { described_class.default_string_limit = nil }
      it     { is_expected.to eq(225) }
    end
  end

  describe '#default_null' do
    subject { described_class.default_null }

    context 'when not explicitly set' do
      it { is_expected.to eq(false) }
    end

    context 'when explicitly set' do
      before { described_class.default_null = true }
      after  { described_class.default_null = false }
      it     { is_expected.to eq(true) }
    end
  end

  describe '#default_generate_foreign_keys' do
    subject { described_class.default_generate_foreign_keys }

    context 'when not explicitly set' do
      it { is_expected.to eq(true) }
    end

    context 'when explicitly set' do
      before { described_class.default_generate_foreign_keys = false }
      after  { described_class.default_generate_foreign_keys = true }
      it     { is_expected.to eq(false) }
    end
  end

  describe '#default_generate_indexing' do
    subject { described_class.default_generate_indexing }

    context 'when not explicitly set' do
      it { is_expected.to eq(true) }
    end

    context 'when explicitly set' do
      before { described_class.default_generate_indexing = false }
      after  { described_class.default_generate_indexing = true }
      it     { is_expected.to eq(false) }
    end
  end

  describe '#max_index_and_constraint_name_length' do
    subject { described_class.max_index_and_constraint_name_length }

    context 'when not explicitly set' do
      it { is_expected.to eq(64) }
    end

    context 'when explicitly set' do
      around do |spec|
        orig_value = described_class.max_index_and_constraint_name_length
        described_class.max_index_and_constraint_name_length = max_index_and_constraint_name_length
        spec.run
      rescue
        described_class.max_index_and_constraint_name_length = orig_value
      end

      context 'when set to an Integer' do
        let(:max_index_and_constraint_name_length) { 255 }

        it { is_expected.to eq(255)}
      end

      context 'when set to nil' do
        let(:max_index_and_constraint_name_length) { nil }

        it { is_expected.to eq(nil)}
      end
    end
  end
end
